// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PointsHook} from "../src/PointsHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import "forge-std/console.sol";

contract DeployPointsHook is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the enhanced Points Hook
        PointsHook hook = new PointsHook(IPoolManager(poolManagerAddress));
        
        vm.stopBroadcast();
        
        console.log("Enhanced Points Hook deployed at:", address(hook));
        console.log("Pool Manager address:", poolManagerAddress);
        
        // Log the hook permissions
        console.log("Hook permissions:");
        console.log("- beforeSwap: false");
        console.log("- afterSwap: true");
        console.log("- beforeMint: false");
        console.log("- afterMint: false");
        console.log("- beforeBurn: false");
        console.log("- afterBurn: false");
    }
} 