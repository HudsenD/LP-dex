// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

error Dex__PoolClosed();
error Dex__InvalidTokenAmount();
error Dex__WrongTokenForPool();

contract Dex is ReentrancyGuard {
  struct Pool {
    ERC20 tokenA;
    ERC20 tokenB;
    bool isOpen;
    uint256 tokenATotal; // total token balance in pool
    uint256 tokenBTotal; // total token balance in pool
  }

  struct LpProvider {
    uint256 tokenABalance; //token user deposited balance in pool
    uint256 tokenBBalance; // token user deposited balance in pool
  }

  // poolName => Pool
  mapping(string => Pool) poolInfo;
  // poolName -> token -> amount?

  // User -> poolName -> struct with token balance specific to user in each ?
  mapping(address => mapping(string => LpProvider)) userPoolBalances;

  // User -> token  ->  amount
  mapping(address => mapping(ERC20 => uint256)) poolTokenBalances;

  // address+poolname -> token -> amount
  mapping(string => mapping(ERC20 => uint256)) userPoolBalances2;

  constructor() {}

  modifier isOpen(string calldata poolName) {
    if (poolInfo[poolName].isOpen == false) {
      revert Dex__PoolClosed();
    }
    _;
  }

  function createPool(ERC20 tokenA, ERC20 tokenB) external {
    string memory symbolA = tokenA.symbol();
    string memory symbolB = tokenB.symbol();
    string memory poolName = string.concat(symbolA, "/", symbolB);
    poolInfo[poolName] = Pool(tokenA, tokenB, true, 0, 0);
    //console.log("new pool created: ", poolName);
  }

  function swap(
    string calldata poolName,
    ERC20 quoteToken,
    uint256 amount
  ) external isOpen(poolName) {}

  function addLiquidityV2(
    string calldata poolName,
    ERC20 token,
    uint256 amount
  ) external isOpen(poolName) {
    token.transferFrom(msg.sender, address(this), amount);
    //string memory key = string.concat(msg.sender, poolName); // lets pretend this works for now.
    //userPoolBalances2[key][token] += amount;
  }

  function addLiquidity(
    string calldata poolName,
    ERC20 token,
    uint256 amount
  ) external isOpen(poolName) {
    Pool memory pool = poolInfo[poolName];

    token.transferFrom(msg.sender, address(this), amount);

    if (token == pool.tokenA) {
      userPoolBalances[msg.sender][poolName].tokenABalance += amount;
      poolInfo[poolName].tokenATotal += amount;
    } else if (token == pool.tokenB) {
      userPoolBalances[msg.sender][poolName].tokenBBalance += amount;
      poolInfo[poolName].tokenBTotal += amount;
    } else {
      revert Dex__WrongTokenForPool();
    }

    // what if someone adds a random token? we dont wanna let them add the wrong one.
    // how do we know which token to add. we can force them to add both. or we can check which one it is. we could also do two functions. one for a one for b
    // gonna just check which one
    //poolTokenBalances[msg.sender][token] += amount;
    //console.log("Tokens Deposited!!");
  }

  //function isTokenAorB(ERC20 token) internal view returns (string memory) {}

  function removeLiquidity(
    string calldata poolName,
    ERC20 token,
    uint256 amount
  ) external isOpen(poolName) {
    //add token check
    if (poolTokenBalances[msg.sender][token] < amount) {
      revert Dex__InvalidTokenAmount();
    }
    poolTokenBalances[msg.sender][token] -= amount;
    token.approve(address(this), amount);
    token.transferFrom(address(this), msg.sender, amount);
    //console.log("Tokens Removed!!");
  }

  // X * Y = K
  function getPrice(
    string calldata poolName,
    ERC20 baseToken
  ) external view returns (uint256) {
    Pool memory pool = poolInfo[poolName];
    // if base token is tokenA, then quote token is tokenB. I think this should work.
    ERC20 quoteToken = (baseToken == pool.tokenA) ? pool.tokenB : pool.tokenA;

    // uint256 quoteTokenSupply = check total balance in pool || and make sure balance is not zero
    // uint256 baseTokenSupply = check total balance in pool || and make sure balacne is not zero
    // return quote / base using safemath
  }

  function isPoolOpen(string calldata poolName) external view returns (bool) {
    return poolInfo[poolName].isOpen;
  }
}
