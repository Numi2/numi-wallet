// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NumiCoin.sol";

contract MiningPool is Ownable, ReentrancyGuard {
    NumiCoin public numiCoin;
    
    struct Miner {
        uint256 shares;
        uint256 lastClaimTime;
        uint256 pendingRewards;
        bool isActive;
    }
    
    struct PoolStats {
        uint256 totalShares;
        uint256 totalRewards;
        uint256 lastRewardTime;
        uint256 rewardPerShare;
    }
    
    mapping(address => Miner) public miners;
    PoolStats public poolStats;
    
    uint256 public minStake = 100 * 10**18; // 100 NUMI minimum stake
    uint256 public maxStake = 10000 * 10**18; // 10,000 NUMI maximum stake
    uint256 public poolFee = 500; // 5% pool fee (in basis points)
    
    event MinerJoined(address indexed miner, uint256 shares);
    event MinerLeft(address indexed miner, uint256 shares);
    event RewardsClaimed(address indexed miner, uint256 amount);
    event PoolReward(uint256 amount, uint256 timestamp);
    
    constructor(address _numiCoin) {
        numiCoin = NumiCoin(_numiCoin);
        poolStats.lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev Join the mining pool by staking NUMI tokens
     */
    function joinPool(uint256 amount) external nonReentrant {
        require(amount >= minStake, "Below minimum stake");
        require(amount <= maxStake, "Above maximum stake");
        require(!miners[msg.sender].isActive, "Already in pool");
        
        // Transfer tokens from miner to pool
        require(
            numiCoin.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        // Update pool stats
        updatePoolRewards();
        
        // Add miner to pool
        miners[msg.sender] = Miner({
            shares: amount,
            lastClaimTime: block.timestamp,
            pendingRewards: 0,
            isActive: true
        });
        
        poolStats.totalShares += amount;
        
        emit MinerJoined(msg.sender, amount);
    }
    
    /**
     * @dev Leave the mining pool and claim rewards
     */
    function leavePool() external nonReentrant {
        Miner storage miner = miners[msg.sender];
        require(miner.isActive, "Not in pool");
        
        // Update pool rewards
        updatePoolRewards();
        
        // Calculate pending rewards
        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        uint256 totalAmount = miner.shares + pendingRewards;
        
        // Remove miner from pool
        poolStats.totalShares -= miner.shares;
        miner.isActive = false;
        miner.shares = 0;
        miner.pendingRewards = 0;
        
        // Transfer tokens back to miner
        require(
            numiCoin.transfer(msg.sender, totalAmount),
            "Transfer failed"
        );
        
        emit MinerLeft(msg.sender, miner.shares);
        if (pendingRewards > 0) {
            emit RewardsClaimed(msg.sender, pendingRewards);
        }
    }
    
    /**
     * @dev Claim pending rewards without leaving pool
     */
    function claimRewards() external nonReentrant {
        Miner storage miner = miners[msg.sender];
        require(miner.isActive, "Not in pool");
        
        updatePoolRewards();
        
        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        require(pendingRewards > 0, "No rewards to claim");
        
        // Reset pending rewards
        miner.pendingRewards = 0;
        miner.lastClaimTime = block.timestamp;
        
        // Transfer rewards
        require(
            numiCoin.transfer(msg.sender, pendingRewards),
            "Transfer failed"
        );
        
        emit RewardsClaimed(msg.sender, pendingRewards);
    }
    
    /**
     * @dev Add mining rewards to the pool (called by NumiCoin contract)
     */
    function addRewards(uint256 amount) external {
        require(msg.sender == address(numiCoin), "Only NumiCoin can add rewards");
        
        updatePoolRewards();
        
        // Apply pool fee
        uint256 feeAmount = (amount * poolFee) / 10000;
        uint256 rewardAmount = amount - feeAmount;
        
        // Update pool stats
        poolStats.totalRewards += rewardAmount;
        poolStats.rewardPerShare += (rewardAmount * 1e18) / poolStats.totalShares;
        
        emit PoolReward(rewardAmount, block.timestamp);
    }
    
    /**
     * @dev Calculate pending rewards for a miner
     */
    function calculatePendingRewards(address miner) public view returns (uint256) {
        Miner storage minerData = miners[miner];
        if (!minerData.isActive || minerData.shares == 0) {
            return 0;
        }
        
        uint256 currentRewardPerShare = poolStats.rewardPerShare;
        if (poolStats.totalShares > 0) {
            // Calculate new rewards since last update
            uint256 timeSinceLastReward = block.timestamp - poolStats.lastRewardTime;
            uint256 newRewards = timeSinceLastReward * 100 * 10**18 / 1 days; // 100 NUMI per day
            currentRewardPerShare += (newRewards * 1e18) / poolStats.totalShares;
        }
        
        uint256 earned = (minerData.shares * currentRewardPerShare) / 1e18;
        uint256 pending = earned - minerData.pendingRewards;
        
        return pending;
    }
    
    /**
     * @dev Update pool rewards
     */
    function updatePoolRewards() internal {
        if (poolStats.totalShares == 0) {
            poolStats.lastRewardTime = block.timestamp;
            return;
        }
        
        uint256 timeSinceLastReward = block.timestamp - poolStats.lastRewardTime;
        if (timeSinceLastReward > 0) {
            uint256 newRewards = timeSinceLastReward * 100 * 10**18 / 1 days; // 100 NUMI per day
            poolStats.totalRewards += newRewards;
            poolStats.rewardPerShare += (newRewards * 1e18) / poolStats.totalShares;
        }
        
        poolStats.lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev Get miner information
     */
    function getMinerInfo(address miner) external view returns (
        uint256 shares,
        uint256 pendingRewards,
        uint256 lastClaimTime,
        bool isActive
    ) {
        Miner storage minerData = miners[miner];
        return (
            minerData.shares,
            calculatePendingRewards(miner),
            minerData.lastClaimTime,
            minerData.isActive
        );
    }
    
    /**
     * @dev Get pool statistics
     */
    function getPoolStats() external view returns (
        uint256 totalShares,
        uint256 totalRewards,
        uint256 lastRewardTime,
        uint256 rewardPerShare,
        uint256 activeMiners
    ) {
        return (
            poolStats.totalShares,
            poolStats.totalRewards,
            poolStats.lastRewardTime,
            poolStats.rewardPerShare,
            poolStats.totalShares > 0 ? 1 : 0 // Simplified active miner count
        );
    }
    
    /**
     * @dev Owner functions for pool management
     */
    function setPoolParams(
        uint256 _minStake,
        uint256 _maxStake,
        uint256 _poolFee
    ) external onlyOwner {
        minStake = _minStake;
        maxStake = _maxStake;
        poolFee = _poolFee;
    }
    
    function withdrawFees() external onlyOwner {
        uint256 balance = numiCoin.balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        
        require(
            numiCoin.transfer(owner(), balance),
            "Transfer failed"
        );
    }
} 