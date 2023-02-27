// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

error Dex__PoolClosed();
error Dex__InsufficientUserFunds();
error Dex__InsufficientPoolFunds();
error Dex__ZeroPoolLiquidity();
error Dex__Erc20TransferFailed();

contract DexV2 is ReentrancyGuard {
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

  function swap(
    string calldata poolName,
    ERC20 quoteToken,
    uint256 depositAmount
  ) external isOpen(poolName) {
    Pool memory pool = poolInfo[poolName];
    ERC20 baseToken = (quoteToken == pool.tokenA) ? pool.tokenB : pool.tokenA;
    uint256 baseTokensToReturn = calculateTokenSwap(
      poolName,
      quoteToken,
      depositAmount,
      baseToken
    );
    // update Pool balances
    totalPoolBalances[poolName][quoteToken] += depositAmount;
    totalPoolBalances[poolName][baseToken] -= baseTokensToReturn;
    // transfer quote tokens from user to contract
    bool quoteSuccess = quoteToken.transferFrom(
      msg.sender,
      address(this),
      depositAmount
    );
    // transer base tokens from contract to user
    baseToken.approve(address(this), baseTokensToReturn);
    bool baseSuccess = baseToken.transferFrom(
      address(this),
      msg.sender,
      baseTokensToReturn
    );

    if (!quoteSuccess || !baseSuccess) {
      revert Dex__Erc20TransferFailed();
    }
  }

  function addLiquidity(
    string calldata poolName,
    ERC20 token,
    uint256 amount
  ) external isOpen(poolName) {
    bool success = token.transferFrom(msg.sender, address(this), amount);
    if (!success) {
      revert Dex__Erc20TransferFailed();
    }
    bytes32 userKey = generateUserKey(poolName, msg.sender);
    userPoolBalances[userKey][token] += amount;
    totalPoolBalances[poolName][token] += amount;
  }

  function removeLiquidity(
    string calldata poolName,
    ERC20 token,
    uint256 amount
  ) external isOpen(poolName) {
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

  // X * Y = K
  function calculateTokenSwap(
    string calldata poolName,
    ERC20 quoteToken,
    uint256 depositAmount,
    ERC20 baseToken
  ) public view returns (uint256) {
    uint256 quoteTokenSupply = totalPoolBalances[poolName][quoteToken];
    uint256 baseTokenSupply = totalPoolBalances[poolName][baseToken];
    if (quoteTokenSupply <= 0 || baseTokenSupply <= 0) {
      revert Dex__ZeroPoolLiquidity();
    }

    uint256 kValue = (baseTokenSupply * quoteTokenSupply);
    uint256 newBaseSupply = (kValue) / (quoteTokenSupply + depositAmount);

    return baseTokenSupply - newBaseSupply;
  }

  function generateUserKey(
    string calldata poolName,
    address user
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(poolName, user));
  }

  function getIsPoolOpen(
    string calldata poolName
  ) external view returns (bool) {
    return poolInfo[poolName].isOpen;
  }

  function getUserPoolBalance(
    string calldata poolName,
    ERC20 token
  ) external view returns (uint256) {
    return userPoolBalances[generateUserKey(poolName, msg.sender)][token];
  }

  function getTotalPoolBalance(
    string calldata poolName,
    ERC20 token
  ) external view returns (uint256) {
    return totalPoolBalances[poolName][token];
  }
}
