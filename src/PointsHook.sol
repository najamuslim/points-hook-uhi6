// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    // Events for tracking
    event PointsMinted(address indexed user, uint256 poolId, uint256 points, uint256 bonusPoints);
    event LeaderboardUpdated(address indexed user, uint256 poolId, uint256 totalPoints);
    
    // Bonus thresholds and multipliers
    uint256 public constant BONUS_THRESHOLD_1 = 0.1 ether; // 0.1 ETH
    uint256 public constant BONUS_THRESHOLD_2 = 1 ether;   // 1 ETH
    uint256 public constant BONUS_MULTIPLIER_1 = 150;      // 50% bonus
    uint256 public constant BONUS_MULTIPLIER_2 = 200;      // 100% bonus
    
    // Leaderboard tracking
    mapping(uint256 => mapping(address => uint256)) public userTotalPoints; // poolId => user => totalPoints
    mapping(uint256 => address[]) public topUsers; // poolId => array of top users
    
    // Swap count tracking
    mapping(uint256 => mapping(address => uint256)) public userSwapCount; // poolId => user => swapCount
    
    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // We only mint points if user is buying TOKEN with ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Calculate ETH spent
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        
        // Calculate base points (20% of ETH spent)
        uint256 basePoints = ethSpendAmount / 5;
        
        // Calculate bonus points based on swap size
        uint256 bonusPoints = _calculateBonusPoints(ethSpendAmount);
        
        // Total points to mint
        uint256 totalPoints = basePoints + bonusPoints;

        // Mint the points
        _assignPoints(key.toId(), hookData, totalPoints, basePoints, bonusPoints);

        return (this.afterSwap.selector, 0);
    }

    function _calculateBonusPoints(uint256 ethAmount) internal pure returns (uint256) {
        uint256 basePoints = ethAmount / 5; // 20% base points
        
        if (ethAmount >= BONUS_THRESHOLD_2) {
            // 100% bonus for swaps >= 1 ETH
            return basePoints;
        } else if (ethAmount >= BONUS_THRESHOLD_1) {
            // 50% bonus for swaps >= 0.1 ETH
            return basePoints / 2;
        }
        
        return 0; // No bonus for small swaps
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 totalPoints,
        uint256 basePoints,
        uint256 bonusPoints
    ) internal {
        // If no hookData is passed in, no points will be assigned to anyone
        if (hookData.length == 0) return;

        // Extract user address from hookData
        address user = abi.decode(hookData, (address));

        // If there is hookData but not in the format we're expecting and user address is zero
        // nobody gets any points
        if (user == address(0)) return;

        // Mint points to the user
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUint, totalPoints, "");
        
        // Update leaderboard
        _updateLeaderboard(poolIdUint, user, totalPoints);
        
        // Update swap count
        userSwapCount[poolIdUint][user]++;
        
        // Emit events
        emit PointsMinted(user, poolIdUint, basePoints, bonusPoints);
        emit LeaderboardUpdated(user, poolIdUint, userTotalPoints[poolIdUint][user]);
    }
    
    function _updateLeaderboard(uint256 poolId, address user, uint256 points) internal {
        // Add points to user's total
        userTotalPoints[poolId][user] += points;
        
        // Add user to top users list if not already there
        address[] storage topUsersList = topUsers[poolId];
        bool userExists = false;
        
        for (uint256 i = 0; i < topUsersList.length; i++) {
            if (topUsersList[i] == user) {
                userExists = true;
                break;
            }
        }
        
        if (!userExists) {
            topUsersList.push(user);
        }
    }
    
    // Public functions to query leaderboard data
    function getUserTotalPoints(uint256 poolId, address user) public view returns (uint256) {
        return userTotalPoints[poolId][user];
    }
    
    function getUserSwapCount(uint256 poolId, address user) public view returns (uint256) {
        return userSwapCount[poolId][user];
    }
    
    function getTopUsers(uint256 poolId) public view returns (address[] memory) {
        return topUsers[poolId];
    }
    
    function getTopUsersWithPoints(uint256 poolId) public view returns (address[] memory users, uint256[] memory points) {
        address[] memory topUsersList = topUsers[poolId];
        users = new address[](topUsersList.length);
        points = new uint256[](topUsersList.length);
        
        for (uint256 i = 0; i < topUsersList.length; i++) {
            users[i] = topUsersList[i];
            points[i] = userTotalPoints[poolId][topUsersList[i]];
        }
    }
}
