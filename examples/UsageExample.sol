// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PointsHook} from "../src/PointsHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

/**
 * @title UsageExample
 * @dev Example contract showing how to interact with the enhanced Points Hook
 */
contract UsageExample {
    PointsHook public hook;
    IPoolManager public poolManager;
    
    constructor(address _hook, address _poolManager) {
        hook = PointsHook(_hook);
        poolManager = IPoolManager(_poolManager);
    }
    
    /**
     * @dev Example function showing how to perform a swap and earn points
     * @param poolKey The pool key for the ETH/TOKEN pool
     * @param ethAmount Amount of ETH to swap
     * @param userAddress Address to receive points
     */
    function swapAndEarnPoints(
        PoolKey calldata poolKey,
        uint256 ethAmount,
        address userAddress
    ) external payable {
        require(msg.value >= ethAmount, "Insufficient ETH sent");
        
        // Encode user address for hook data
        bytes memory hookData = abi.encode(userAddress);
        
        // Create swap parameters
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true, // ETH to TOKEN
            amountSpecified: -int256(ethAmount), // Negative for exact input
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        // Perform the swap (this would typically be done through a router)
        // The hook will automatically mint points to the user
        // poolManager.swap(poolKey, swapParams, hookData);
        
        // After swap, you can query the user's points
        uint256 poolId = uint256(poolKey.toId());
        uint256 userPoints = hook.getUserTotalPoints(poolId, userAddress);
        uint256 userSwapCount = hook.getUserSwapCount(poolId, userAddress);
        
        // You can also get leaderboard data
        address[] memory topUsers = hook.getTopUsers(poolId);
        (address[] memory users, uint256[] memory points) = hook.getTopUsersWithPoints(poolId);
    }
    
    /**
     * @dev Get user statistics for a pool
     * @param poolId The pool ID
     * @param user The user address
     * @return totalPoints Total points earned by user
     * @return swapCount Number of swaps by user
     * @return currentBalance Current point balance
     */
    function getUserStats(uint256 poolId, address user) external view returns (
        uint256 totalPoints,
        uint256 swapCount,
        uint256 currentBalance
    ) {
        totalPoints = hook.getUserTotalPoints(poolId, user);
        swapCount = hook.getUserSwapCount(poolId, user);
        currentBalance = hook.balanceOf(user, poolId);
    }
    
    /**
     * @dev Get leaderboard data for a pool
     * @param poolId The pool ID
     * @return users Array of user addresses
     * @return points Array of total points for each user
     */
    function getLeaderboard(uint256 poolId) external view returns (
        address[] memory users,
        uint256[] memory points
    ) {
        return hook.getTopUsersWithPoints(poolId);
    }
    
    /**
     * @dev Calculate expected points for a swap amount
     * @param ethAmount Amount of ETH to swap
     * @return basePoints Base points (20% of ETH amount)
     * @return bonusPoints Bonus points based on swap size
     * @return totalPoints Total points (base + bonus)
     */
    function calculateExpectedPoints(uint256 ethAmount) external pure returns (
        uint256 basePoints,
        uint256 bonusPoints,
        uint256 totalPoints
    ) {
        basePoints = ethAmount / 5; // 20% base points
        
        if (ethAmount >= 1 ether) {
            // 100% bonus for swaps >= 1 ETH
            bonusPoints = basePoints;
        } else if (ethAmount >= 0.1 ether) {
            // 50% bonus for swaps >= 0.1 ETH
            bonusPoints = basePoints / 2;
        } else {
            // No bonus for small swaps
            bonusPoints = 0;
        }
        
        totalPoints = basePoints + bonusPoints;
    }
} 