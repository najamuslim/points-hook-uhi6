# Enhanced Points Hook - Uniswap v4 Hook with Bonus System

This is an enhanced version of the original Points Hook that adds a bonus points system, leaderboard tracking, and swap count monitoring.

## Features Added

### 1. Bonus Points System

- **Small Swaps** (< 0.1 ETH): No bonus, only base 20% points
- **Medium Swaps** (0.1-1 ETH): 50% bonus on top of base points
- **Large Swaps** (≥ 1 ETH): 100% bonus on top of base points

### 2. Leaderboard Tracking

- Tracks total points accumulated per user per pool
- Maintains list of top users for each pool
- Provides query functions to get leaderboard data

### 3. Swap Count Monitoring

- Tracks number of swaps per user per pool
- Useful for analytics and user engagement metrics

### 4. Enhanced Events

- `PointsMinted`: Emitted when points are awarded, includes base and bonus points
- `LeaderboardUpdated`: Emitted when user's total points are updated

## How It Works

### Original Points Hook Logic

- Users get 20% of ETH spent as points when swapping ETH for tokens
- Points are minted as ERC-1155 tokens with pool ID as token ID
- Users must provide their address in `hookData` to receive points

### Enhanced Features

#### Bonus Calculation

```solidity
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
```

#### Leaderboard Management

```solidity
function _updateLeaderboard(uint256 poolId, address user, uint256 points) internal {
    // Add points to user's total
    userTotalPoints[poolId][user] += points;

    // Add user to top users list if not already there
    // ... implementation
}
```

## Usage

### 1. Basic Swap with Points

```solidity
// Encode user address in hook data
bytes memory hookData = abi.encode(userAddress);

// Perform swap
swapRouter.swap{value: ethAmount}(
    key,
    SwapParams({
        zeroForOne: true,
        amountSpecified: -ethAmount,
        sqrtPriceLimitX96: minSqrtPrice
    }),
    settings,
    hookData
);
```

### 2. Query Leaderboard Data

```solidity
// Get user's total points for a pool
uint256 totalPoints = hook.getUserTotalPoints(poolId, userAddress);

// Get user's swap count for a pool
uint256 swapCount = hook.getUserSwapCount(poolId, userAddress);

// Get all top users for a pool
address[] memory topUsers = hook.getTopUsers(poolId);

// Get top users with their points
(address[] memory users, uint256[] memory points) = hook.getTopUsersWithPoints(poolId);
```

## Testing

The enhanced hook includes comprehensive tests:

- `test_swap()`: Original basic swap test
- `test_bonus_points_small_swap()`: Tests small swaps with no bonus
- `test_bonus_points_medium_swap()`: Tests medium swaps with 50% bonus
- `test_bonus_points_large_swap()`: Tests large swaps with 100% bonus
- `test_leaderboard_tracking()`: Tests leaderboard functionality
- `test_multiple_swaps_same_user()`: Tests multiple swaps by same user
- `test_no_points_without_hookdata()`: Tests edge case with no hook data
- `test_no_points_with_zero_address()`: Tests edge case with zero address

Run tests with:

```bash
forge test
```

## Deployment

1. Build the project:

```bash
forge build
```

2. Deploy the hook:

```bash
forge script Deploy --rpc-url <your-rpc-url> --private-key <your-private-key> --broadcast
```

## Key Improvements Over Original

1. **Incentive Structure**: Bonus system encourages larger trades
2. **Gamification**: Leaderboard creates competitive environment
3. **Analytics**: Swap count tracking provides insights
4. **Events**: Better event system for frontend integration
5. **Query Functions**: Easy access to leaderboard data

## Technical Details

### Constants

- `BONUS_THRESHOLD_1`: 0.1 ETH (50% bonus threshold)
- `BONUS_THRESHOLD_2`: 1 ETH (100% bonus threshold)

### Storage

- `userTotalPoints`: Mapping of poolId => user => total points
- `topUsers`: Mapping of poolId => array of user addresses
- `userSwapCount`: Mapping of poolId => user => swap count

### Events

- `PointsMinted(address user, uint256 poolId, uint256 points, uint256 bonusPoints)`
- `LeaderboardUpdated(address user, uint256 poolId, uint256 totalPoints)`

## Future Enhancements

1. **Time-based bonuses**: Different bonuses for different time periods
2. **Referral system**: Bonus points for referring new users
3. **Achievement system**: Special rewards for milestones
4. **Pool-specific bonuses**: Different bonus rates for different pools
5. **Governance**: Allow community to vote on bonus rates

## Security Considerations

- Hook only processes ETH-TOKEN swaps (currency0 must be zero address)
- Hook only processes zeroForOne swaps (ETH to TOKEN)
- Points are only minted when valid user address is provided in hookData
- All calculations use safe arithmetic operations
- Events provide transparency for all point distributions

## License

MIT License - see LICENSE file for details.
