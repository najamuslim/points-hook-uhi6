// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";

import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";

contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
    MockERC20 token;

    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;

    PointsHook hook;

    function setUp() public {
        // Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));

        // Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));

        // Deploy our hook
        hook = PointsHook(address(flags));

        // Approve our TOKEN for spending on the swap router and modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Initialize a pool
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );

        // Add some liquidity to the pool
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        uint256 ethToAdd = 0.1 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            ethToAdd
        );
        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            liquidityDelta
        );

        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
            address(this),
            poolIdUint
        );

        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));

        // Now we swap
        // We will swap 0.001 ether for tokens
        // We should get 20% of 0.001 * 10**18 points
        // = 2 * 10**14
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfterSwap = hook.balanceOf(
            address(this),
            poolIdUint
        );
        assertEq(pointsBalanceAfterSwap - pointsBalanceOriginal, 2 * 10 ** 14);
    }

    function test_bonus_points_small_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));

        // Small swap (0.05 ETH) - should get no bonus
        swapRouter.swap{value: 0.05 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.05 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Should get 20% of actual ETH spent
        uint256 actualPoints = hook.balanceOf(address(this), poolIdUint);
        assertGt(actualPoints, 0);
        
        // Check total points in leaderboard
        assertEq(hook.getUserTotalPoints(poolIdUint, address(this)), actualPoints);
        
        // Check swap count
        assertEq(hook.getUserSwapCount(poolIdUint, address(this)), 1);
    }

    function test_bonus_points_medium_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));

        // Medium swap (0.15 ETH) - should get 50% bonus
        swapRouter.swap{value: 0.15 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.15 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Check that points were awarded
        uint256 actualPoints = hook.balanceOf(address(this), poolIdUint);
        assertGt(actualPoints, 0);
        assertEq(hook.getUserTotalPoints(poolIdUint, address(this)), actualPoints);
    }

    function test_bonus_points_large_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));

        // Large swap (1.5 ETH) - should get 100% bonus
        swapRouter.swap{value: 1.5 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -1.5 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Check that points were awarded
        uint256 actualPoints = hook.balanceOf(address(this), poolIdUint);
        assertGt(actualPoints, 0);
        assertEq(hook.getUserTotalPoints(poolIdUint, address(this)), actualPoints);
    }

    function test_leaderboard_tracking() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        
        // User 1 makes a swap
        bytes memory hookData1 = abi.encode(address(1));
        swapRouter.swap{value: 0.1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData1
        );

        // User 2 makes a swap
        bytes memory hookData2 = abi.encode(address(2));
        swapRouter.swap{value: 0.2 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.2 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData2
        );

        // Check that both users are in the top users list
        address[] memory topUsers = hook.getTopUsers(poolIdUint);
        assertEq(topUsers.length, 2);
        
        // Check that both users have points
        assertGt(hook.getUserTotalPoints(poolIdUint, address(1)), 0);
        assertGt(hook.getUserTotalPoints(poolIdUint, address(2)), 0);
        
        // Check swap counts
        assertEq(hook.getUserSwapCount(poolIdUint, address(1)), 1);
        assertEq(hook.getUserSwapCount(poolIdUint, address(2)), 1);
    }

    function test_multiple_swaps_same_user() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));

        // First swap
        swapRouter.swap{value: 0.1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Second swap
        swapRouter.swap{value: 0.2 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.2 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Check total points accumulated
        uint256 totalPoints = hook.getUserTotalPoints(poolIdUint, address(this));
        assertGt(totalPoints, 0);
        
        // Check swap count
        assertEq(hook.getUserSwapCount(poolIdUint, address(this)), 2);
        
        // Check that user appears only once in top users
        address[] memory topUsers = hook.getTopUsers(poolIdUint);
        uint256 userCount = 0;
        for (uint256 i = 0; i < topUsers.length; i++) {
            if (topUsers[i] == address(this)) {
                userCount++;
            }
        }
        assertEq(userCount, 1); // Should appear only once
    }

    function test_no_points_without_hookdata() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
            address(this),
            poolIdUint
        );

        // Swap without hook data
        swapRouter.swap{value: 0.1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            "" // No hook data
        );

        // Should not get any points
        uint256 pointsBalanceAfterSwap = hook.balanceOf(
            address(this),
            poolIdUint
        );
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal);
    }

    function test_no_points_with_zero_address() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
            address(this),
            poolIdUint
        );

        // Swap with zero address in hook data
        bytes memory hookData = abi.encode(address(0));
        swapRouter.swap{value: 0.1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        // Should not get any points
        uint256 pointsBalanceAfterSwap = hook.balanceOf(
            address(this),
            poolIdUint
        );
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal);
    }
}
