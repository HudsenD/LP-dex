// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// need to track how much lp is provided by minting a token so ppl can withdraw all funds even when the price is much different then when they deoposited

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error Dex__PoolClosed();
error Dex__InsufficientUserFunds();
error Dex__InsufficientPoolFunds();
error Dex__ZeroPoolLiquidity();
error Dex__Erc20TransferFailed();

contract DexV3 is ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public lastRewardDistributionTimestamp;
    uint256 public rewardDistributionInterval = 86400; // 1 day in seconds

    struct Pool {
        ERC20 tokenA;
        ERC20 tokenB;
        bool isOpen;
    }

    // poolName => Pool
    mapping(string => Pool) poolInfo;

    // poolName -> token -> amount
    mapping(string => mapping(ERC20 => uint256)) totalPoolBalances;

    // address+poolname -> token -> amount
    mapping(bytes32 => mapping(ERC20 => uint256)) userPoolBalances;

    constructor() {}

    modifier isOpen(string calldata poolName) {
        if (!poolInfo[poolName].isOpen) {
            revert Dex__PoolClosed();
        }
        _;
    }

    // maybe make modifer that checks token they add is in pool

    function createPool(ERC20 tokenA, ERC20 tokenB) external {
        string memory symbolA = tokenA.symbol();
        string memory symbolB = tokenB.symbol();
        string memory poolName = string.concat(symbolA, "/", symbolB);
        poolInfo[poolName] = Pool(tokenA, tokenB, true);
    }

    function swap(string calldata poolName, ERC20 quoteToken, uint256 depositAmount) external isOpen(poolName) {
        Pool memory pool = poolInfo[poolName];
        ERC20 baseToken = (quoteToken == pool.tokenA) ? pool.tokenB : pool.tokenA;
        uint256 fee = depositAmount.mul(3).div(1000);
        // add fee to some mapping here
        depositAmount = depositAmount.sub(fee);
        uint256 baseTokensToReturn = calculateTokenSwap(poolName, quoteToken, depositAmount, baseToken);
        // update Pool balances
        totalPoolBalances[poolName][quoteToken] += depositAmount;
        totalPoolBalances[poolName][baseToken] -= baseTokensToReturn;
        // transfer quote tokens from user to contract
        bool quoteSuccess = quoteToken.transferFrom(msg.sender, address(this), depositAmount);
        // transer base tokens from contract to user
        baseToken.approve(address(this), baseTokensToReturn);
        bool baseSuccess = baseToken.transferFrom(address(this), msg.sender, baseTokensToReturn);

        if (!quoteSuccess || !baseSuccess) {
            revert Dex__Erc20TransferFailed();
        }
    }

    function userAddLiquidity(
        string calldata poolName,
        ERC20 quoteToken,
        uint256 tokenAmount
    ) external isOpen(poolName) {
        (uint256 baseTokenToDeposit, ERC20 baseToken) = calculateAmountForRatio(poolName, quoteToken, tokenAmount);
        // call addLiquidity for both tokens
        _addLiquidity(poolName, quoteToken, tokenAmount);
        _addLiquidity(poolName, baseToken, baseTokenToDeposit);
    }

    function _addLiquidity(string calldata poolName, ERC20 token, uint256 amount) internal {
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert Dex__Erc20TransferFailed();
        }
        bytes32 userKey = generateUserKey(poolName, msg.sender);
        userPoolBalances[userKey][token] += amount;
        totalPoolBalances[poolName][token] += amount;
    }

    function userRemoveLiquidity(
        string calldata poolName,
        ERC20 quoteToken,
        uint256 tokenAmount
    ) external isOpen(poolName) {
        (uint256 baseTokenToWithdraw, ERC20 baseToken) = calculateAmountForRatio(poolName, quoteToken, tokenAmount);
        // call reomoveLiquidity for both tokens
        _removeLiquidity(poolName, quoteToken, tokenAmount);
        _removeLiquidity(poolName, baseToken, baseTokenToWithdraw);
    }

    function _removeLiquidity(string calldata poolName, ERC20 token, uint256 amount) internal {
        bytes32 userKey = generateUserKey(poolName, msg.sender);

        if (userPoolBalances[userKey][token] < amount) {
            revert Dex__InsufficientUserFunds();
        }

        if (totalPoolBalances[poolName][token] < amount) {
            revert Dex__InsufficientPoolFunds();
        }
        userPoolBalances[userKey][token] -= amount;
        totalPoolBalances[poolName][token] -= amount;
        token.approve(address(this), amount);
        bool success = token.transferFrom(address(this), msg.sender, amount);
        if (!success) {
            revert Dex__Erc20TransferFailed();
        }
    }

    function calculateAmountForRatio(
        string calldata poolName,
        ERC20 quoteToken,
        uint256 tokenAmount
    ) internal view returns (uint256, ERC20) {
        // get current ratio
        Pool memory pool = poolInfo[poolName];
        ERC20 baseToken = (quoteToken == pool.tokenA) ? pool.tokenB : pool.tokenA;
        // need to fix this, when someone deposits for the first time this will have issues
        uint256 quoteTokenPool = totalPoolBalances[poolName][quoteToken];
        uint256 baseTokenPool = totalPoolBalances[poolName][baseToken];
        uint256 currentRatio = quoteTokenPool / baseTokenPool; // this will have no decimal, might need to add some zeros
        // calculate needed token amount for other token to keep current ratio
        uint256 newQuoteTokenPool = quoteTokenPool + tokenAmount;
        uint256 newBaseTokenPool = newQuoteTokenPool / currentRatio;
        uint256 baseTokenToTransact = newBaseTokenPool - baseTokenPool;
        return (baseTokenToTransact, baseToken);
    }

    // X * Y = K
    function calculateTokenSwap(
        string calldata poolName,
        ERC20 quoteToken,
        uint256 depositAmount,
        ERC20 baseToken
    ) internal view returns (uint256) {
        uint256 quoteTokenSupply = totalPoolBalances[poolName][quoteToken];
        uint256 baseTokenSupply = totalPoolBalances[poolName][baseToken];
        if (quoteTokenSupply <= 0 || baseTokenSupply <= 0) {
            revert Dex__ZeroPoolLiquidity();
        }

        uint256 kValue = (baseTokenSupply * quoteTokenSupply);
        uint256 newBaseSupply = (kValue) / (quoteTokenSupply + depositAmount);

        return baseTokenSupply - newBaseSupply;
    }

    // // from AI
    // function paySwapFees() public {
    //     // Get the current time
    //     uint256 now = block.timestamp;

    //     // Calculate the start and end times for the current day
    //     uint256 startOfDay = now - (now % 86400);
    //     uint256 endOfDay = startOfDay + 86400;

    //     // Get the total swap fees collected during the current day
    //     uint256 totalFees = getTotalSwapFees(startOfDay, endOfDay);

    //     // Calculate the amount of fees to be paid to each liquidity provider
    //     uint256 feesPerProvider = totalFees / liquidityProviders.length;

    //     // Pay the fees to each liquidity provider
    //     for (uint256 i = 0; i < liquidityProviders.length; i++) {
    //         liquidityProviders[i].transfer(feesPerProvider);
    //     }
    // }

    function generateUserKey(string calldata poolName, address user) internal pure returns (bytes32) {
        return keccak256(abi.encode(poolName, user));
    }

    function getIsPoolOpen(string calldata poolName) external view returns (bool) {
        return poolInfo[poolName].isOpen;
    }

    function getUserPoolBalance(string calldata poolName, ERC20 token) external view returns (uint256) {
        return userPoolBalances[generateUserKey(poolName, msg.sender)][token];
    }

    function getTotalPoolBalance(string calldata poolName, ERC20 token) external view returns (uint256) {
        return totalPoolBalances[poolName][token];
    }
}
