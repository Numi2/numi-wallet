// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NumiCoin is ERC20, Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    using SafeMath for uint256;

    // Mining configuration - MADE MUCH EASIER FOR PEOPLE'S COIN
    uint256 public difficulty = 2; // Reduced from 4 to 2 - much easier to mine!
    uint256 public blockReward = 500 * 10**18; // Increased from 100 to 500 NumiCoin per block - more generous!
    uint256 public currentBlock = 1;
    uint256 public lastMineTime;
    uint256 public targetMineTime = 30 seconds; // Reduced from 10 minutes to 30 seconds - faster blocks!
    uint256 public maxDifficulty = 6; // Reduced from 8 to 6 - keeps it accessible
    uint256 public minDifficulty = 1; // Reduced from 2 to 1 - very easy for beginners
    
    // Staking and governance - made more accessible
    uint256 public totalStaked;
    uint256 public stakingRewardRate = 1000; // Increased from 500 to 1000 - 10% APY for better rewards
    uint256 public lastStakingRewardTime;
    uint256 public governanceThreshold = 100 * 10**18; // Reduced from 1000 to 100 NUMI staked to propose - more democratic!
    
    // Mining state
    mapping(uint256 => bool) public minedBlocks;
    mapping(address => uint256) public minerRewards;
    mapping(address => uint256) public lastMineBlock;
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public pendingStakingRewards;
    
    // Governance - now based on staked tokens
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    
    // Events
    event BlockMined(
        uint256 indexed blockNumber,
        address indexed miner,
        bytes32 blockHash,
        uint256 nonce,
        uint256 reward,
        uint256 timestamp
    );
    
    event DifficultyAdjusted(uint256 oldDifficulty, uint256 newDifficulty);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event StakingRewardsClaimed(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event MiningPaused(address indexed by);
    event MiningResumed(address indexed by);

    constructor() ERC20("NumiCoin", "NUMI") {
        lastMineTime = block.timestamp;
        lastStakingRewardTime = block.timestamp;
        // NO INITIAL TOKEN DISTRIBUTION - tokens can only be earned through mining
        // This ensures NumiCoin is truly a people's coin, earned through work!
    }

    /**
     * @dev Mine a new block by providing a valid nonce
     * @param nonce The nonce that produces a valid hash
     * @param blockData Additional block data for hashing
     */
    function mineBlock(uint256 nonce, bytes calldata blockData) 
        external 
        nonReentrant 
        whenNotPaused
    {
        require(!minedBlocks[currentBlock], "Block already mined");
        require(block.timestamp >= lastMineTime + 1, "Mining too fast");
        
        // Create block hash
        bytes32 blockHash = keccak256(abi.encodePacked(
            currentBlock,
            msg.sender,
            nonce,
            blockData,
            block.timestamp
        ));
        
        // Verify hash meets difficulty requirement
        require(isValidHash(blockHash), "Invalid hash for current difficulty");
        
        // Mark block as mined
        minedBlocks[currentBlock] = true;
        lastMineBlock[msg.sender] = currentBlock;
        
        // Calculate reward (may be reduced if mining too frequently)
        uint256 reward = calculateReward(msg.sender);
        
        // Mint tokens to miner
        _mint(msg.sender, reward);
        minerRewards[msg.sender] = minerRewards[msg.sender].add(reward);
        
        // Update mining state
        uint256 oldDifficulty = difficulty;
        adjustDifficulty();
        currentBlock++;
        lastMineTime = block.timestamp;
        
        emit BlockMined(
            currentBlock - 1,
            msg.sender,
            blockHash,
            nonce,
            reward,
            block.timestamp
        );
        
        if (difficulty != oldDifficulty) {
            emit DifficultyAdjusted(oldDifficulty, difficulty);
        }
    }

    /**
     * @dev Stake NUMI tokens to earn staking rewards and gain voting power
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Claim existing staking rewards first
        if (stakedAmount[msg.sender] > 0) {
            _claimStakingRewards(msg.sender);
        }
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        // Update staking state
        stakedAmount[msg.sender] = stakedAmount[msg.sender].add(amount);
        totalStaked = totalStaked.add(amount);
        lastStakeTime[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Unstake NUMI tokens (reduces voting power)
     */
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(stakedAmount[msg.sender] >= amount, "Insufficient staked amount");
        
        // Claim staking rewards first
        _claimStakingRewards(msg.sender);
        
        // Update staking state
        stakedAmount[msg.sender] = stakedAmount[msg.sender].sub(amount);
        totalStaked = totalStaked.sub(amount);
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Claim staking rewards
     */
    function claimStakingRewards() external nonReentrant {
        require(stakedAmount[msg.sender] > 0, "No staked amount");
        _claimStakingRewards(msg.sender);
    }

    /**
     * @dev Create a governance proposal (requires staked tokens)
     */
    function createProposal(string calldata description) external {
        require(stakedAmount[msg.sender] >= governanceThreshold, "Insufficient staked tokens for proposal");
        require(bytes(description).length > 0, "Empty description");
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days, // 7 day voting period
            executed: false,
            canceled: false
        });
        
        emit ProposalCreated(proposalCount, msg.sender, description);
    }

    /**
     * @dev Vote on a proposal using staked tokens as voting power
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id == proposalId, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.executed && !proposal.canceled, "Proposal already executed or canceled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        uint256 votingPower = stakedAmount[msg.sender];
        require(votingPower > 0, "No voting power - must stake tokens to vote");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposal.forVotes = proposal.forVotes.add(votingPower);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votingPower);
        }
        
        emit Voted(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @dev Execute a proposal (owner only for now)
     */
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id == proposalId, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(proposal.forVotes > proposal.againstVotes, "Proposal not passed");
        
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Get voting power for an address (based on staked tokens)
     */
    function getVotingPower(address voter) external view returns (uint256) {
        return stakedAmount[voter];
    }

    /**
     * @dev Get total voting power (total staked tokens)
     */
    function getTotalVotingPower() external view returns (uint256) {
        return totalStaked;
    }

    /**
     * @dev Pause mining (emergency function)
     */
    function pauseMining() external onlyOwner {
        _pause();
        emit MiningPaused(msg.sender);
    }

    /**
     * @dev Resume mining
     */
    function resumeMining() external onlyOwner {
        _unpause();
        emit MiningResumed(msg.sender);
    }

    /**
     * @dev Check if a hash meets the current difficulty requirement
     */
    function isValidHash(bytes32 hash) public view returns (bool) {
        uint256 target = (2**256 - 1) / (2**(difficulty * 4));
        return uint256(hash) <= target;
    }

    /**
     * @dev Calculate mining reward for a miner - MORE GENEROUS FOR PEOPLE'S COIN
     */
    function calculateReward(address miner) public view returns (uint256) {
        uint256 baseReward = blockReward;
        
        // Reduced penalty for consecutive mining - more forgiving for regular miners
        if (lastMineBlock[miner] == currentBlock - 1) {
            baseReward = baseReward.mul(75).div(100); // Only 25% reduction instead of 50%
        }
        
        return baseReward;
    }

    /**
     * @dev Calculate pending staking rewards for a user
     */
    function calculateStakingRewards(address user) public view returns (uint256) {
        if (stakedAmount[user] == 0) return 0;
        
        uint256 timeStaked = block.timestamp.sub(lastStakeTime[user]);
        uint256 rewardRate = stakingRewardRate.mul(1e18).div(365 days).div(10000); // Convert to per-second rate
        uint256 rewards = stakedAmount[user].mul(rewardRate).mul(timeStaked).div(1e18);
        
        return rewards.add(pendingStakingRewards[user]);
    }

    /**
     * @dev Adjust difficulty based on mining speed - MORE GRADUAL FOR PEOPLE'S COIN
     */
    function adjustDifficulty() internal {
        uint256 timeSinceLastMine = block.timestamp.sub(lastMineTime);
        
        // More gradual difficulty adjustment - less aggressive
        if (timeSinceLastMine < targetMineTime.div(3)) {
            // Mining very fast, increase difficulty slowly
            if (difficulty < maxDifficulty) {
                difficulty = difficulty.add(1);
            }
        } else if (timeSinceLastMine > targetMineTime.mul(3)) {
            // Mining very slow, decrease difficulty to help miners
            if (difficulty > minDifficulty) {
                difficulty = difficulty.sub(1);
            }
        }
        // If mining speed is reasonable, keep difficulty stable
    }

    /**
     * @dev Internal function to claim staking rewards
     */
    function _claimStakingRewards(address user) internal {
        uint256 rewards = calculateStakingRewards(user);
        require(rewards > 0, "No rewards to claim");
        
        pendingStakingRewards[user] = 0;
        lastStakeTime[user] = block.timestamp;
        
        _mint(user, rewards);
        
        emit StakingRewardsClaimed(user, rewards);
    }

    /**
     * @dev Get current mining statistics
     */
    function getMiningStats() external view returns (
        uint256 _currentBlock,
        uint256 _difficulty,
        uint256 _blockReward,
        uint256 _lastMineTime,
        uint256 _targetMineTime
    ) {
        return (currentBlock, difficulty, blockReward, lastMineTime, targetMineTime);
    }

    /**
     * @dev Get miner statistics
     */
    function getMinerStats(address miner) external view returns (
        uint256 totalRewards,
        uint256 lastMinedBlock,
        uint256 currentReward
    ) {
        return (
            minerRewards[miner],
            lastMineBlock[miner],
            calculateReward(miner)
        );
    }

    /**
     * @dev Get staking statistics
     */
    function getStakingStats(address user) external view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 lastStakeTime
    ) {
        return (
            stakedAmount[user],
            calculateStakingRewards(user),
            lastStakeTime[user]
        );
    }

    /**
     * @dev Get proposal information
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool canceled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.canceled
        );
    }

    /**
     * @dev Emergency function to adjust difficulty (owner only)
     */
    function setDifficulty(uint256 newDifficulty) external onlyOwner {
        require(newDifficulty >= minDifficulty && newDifficulty <= maxDifficulty, "Difficulty out of range");
        uint256 oldDifficulty = difficulty;
        difficulty = newDifficulty;
        emit DifficultyAdjusted(oldDifficulty, difficulty);
    }

    /**
     * @dev Emergency function to adjust block reward (owner only)
     */
    function setBlockReward(uint256 newReward) external onlyOwner {
        require(newReward > 0, "Reward must be positive");
        blockReward = newReward;
    }

    /**
     * @dev Emergency function to adjust governance threshold (owner only)
     */
    function setGovernanceThreshold(uint256 newThreshold) external onlyOwner {
        governanceThreshold = newThreshold;
    }

    /**
     * @dev Override decimals to match standard
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev Override transfer to handle staking
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._transfer(from, to, amount);
    }
} 