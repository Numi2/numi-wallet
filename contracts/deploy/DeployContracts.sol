// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../NumiCoin.sol";
import "../MiningPool.sol";

contract DeployContracts {
    NumiCoin public numiCoin;
    MiningPool public miningPool;
    
    event ContractsDeployed(
        address numiCoin,
        address miningPool,
        address deployer
    );
    
    constructor() {
        // Deploy NumiCoin contract
        numiCoin = new NumiCoin();
        
        // Deploy MiningPool contract with NumiCoin address
        miningPool = new MiningPool(address(numiCoin));
        
        // Transfer ownership of NumiCoin to deployer for initial setup
        numiCoin.transferOwnership(msg.sender);
        
        emit ContractsDeployed(
            address(numiCoin),
            address(miningPool),
            msg.sender
        );
    }
    
    /**
     * @dev Get deployed contract addresses
     */
    function getDeployedAddresses() external view returns (
        address _numiCoin,
        address _miningPool
    ) {
        return (address(numiCoin), address(miningPool));
    }
} 