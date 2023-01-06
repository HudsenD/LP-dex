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

contract DexV2Old is ReentrancyGuard {
    struct Pool {
        ERC20 tokenA; //maybe i could add mapping here instead. would be ERC20 => ERC20
        ERC20 tokenB;
        bool isOpen;
    }

    //Dont forget about s_naming
    // no struct needed. have simple mapping for checking if pool exists. actually might need struct again to make sure users are not depositing wrong tokens
    // poolName => true or false
    mapping(string => Pool) poolInfo; // see if poolName can be bytes32 or if it has to be bytes or string.

    // poolName -> token -> amount?? but what if someone trys to deposit the wrong token? a token that isnt in the
    mapping(string => mapping(ERC20 => uint256)) totalPoolBalances;

    // what if i concat strings of address+poolname?? ok i think this might be big brain. use keckkack
    // address+poolname -> token -> amount
    mapping(bytes32 => mapping(ERC20 => uint256)) userPoolBalances; // these mapping could maybe be combined into one. since the entry hash will be different

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
        //console.log("new pool created: ", poolName);
    }

    function swap(
        string calldata poolName,
        ERC20 quoteToken,
        uint256 depositAmount
    ) external isOpen(poolName) {
        Pool memory pool = poolInfo[poolName];
        ERC20 baseToken = (quoteToken == pool.tokenA) ? pool.tokenB : pool.tokenA;
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

    function addLiquidity(
        string calldata poolName,
        ERC20 token,
        uint256 amount
    ) external isOpen(poolName) {
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert Dex__Erc20TransferFailed();
        }
        bytes32 key = keccak256(abi.encode(poolName, msg.sender));
        userPoolBalances[key][token] += amount; //we add balance to user
        totalPoolBalances[poolName][token] += amount; // we add balance to pool
    }

    function removeLiquidity(
        string calldata poolName,
        ERC20 token,
        uint256 amount
    ) external isOpen(poolName) {
        bytes32 key = keccak256(abi.encode(poolName, msg.sender));
        // check user balance //we also need to check pool balance
        if (userPoolBalances[key][token] < amount) {
            revert Dex__InsufficientUserFunds();
        }

        if (totalPoolBalances[poolName][token] < amount) {
            revert Dex__InsufficientPoolFunds();
        }
        userPoolBalances[key][token] -= amount; // subtract user balance
        totalPoolBalances[poolName][token] -= amount; // subtract pool balance
        token.approve(address(this), amount);
        bool success = token.transferFrom(address(this), msg.sender, amount); // approve and transfer
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
    ) internal view returns (uint256) {
        // Pool memory pool = poolInfo[poolName];
        // ERC20 baseToken = (quoteToken == pool.tokenA) ? pool.tokenB : pool.tokenA;
        uint256 quoteTokenSupply = totalPoolBalances[poolName][quoteToken]; //check total balance in pool || and make sure balance is not zero
        uint256 baseTokenSupply = totalPoolBalances[poolName][baseToken]; //check total balance in pool || and make sure balacne is not zero
        if (quoteTokenSupply <= 0 || baseTokenSupply <= 0) {
            revert Dex__ZeroPoolLiquidity();
        }

        uint256 kValue = (baseTokenSupply * quoteTokenSupply);
        uint256 newBaseSupply = (kValue) / (quoteTokenSupply + depositAmount);
        //return baseSupply - newBaseSupply

        return baseTokenSupply - newBaseSupply;
    } // we can just pass along quote token to getCurrentK

    // X * Y = K
    // function getCurrentK(
    //     string calldata poolName,
    //     ERC20 baseToken,
    //     ERC20 quoteToken
    // ) public view returns (uint256) {
    //     // should i Make this public or internal
    //     // Pool memory pool = poolInfo[poolName];
    //     // // if base token is tokenA, then quote token is tokenB. I think this should work.
    //     // ERC20 quoteToken = (baseToken == pool.tokenA) ? pool.tokenB : pool.tokenA;

    //     uint256 quoteTokenSupply = totalPoolBalances[poolName][quoteToken]; //check total balance in pool || and make sure balance is not zero
    //     uint256 baseTokenSupply = totalPoolBalances[poolName][baseToken]; //check total balance in pool || and make sure balacne is not zero
    //     if (quoteTokenSupply <= 0 || baseTokenSupply <= 0) {
    //         revert Dex__InsufficientPoolLiquidity();
    //     }
    //     return quoteTokenSupply * baseTokenSupply; // return quote / base using safemath
    // }

    function isPoolOpen(string calldata poolName) external view returns (bool) {
        return poolInfo[poolName].isOpen;
    }

    // function getPoolName(ERC20 tokenA, ERC20 tokenB) external view returns (string memory) {
    //     // this function probably isn't neccesary
    //     string memory symbolA = tokenA.symbol();
    //     string memory symbolB = tokenB.symbol();
    //     string memory poolName = string.concat(symbolA, "/", symbolB);
    //     return poolName;
    // }

    function getUserPoolBalance(string calldata poolName, ERC20 token) external view returns (uint256) {
        bytes32 key = keccak256(abi.encode(poolName, msg.sender));
        return userPoolBalances[key][token];
    }

    function getTotalPoolBalance(string calldata poolName, ERC20 token) external view returns (uint256) {
        return totalPoolBalances[poolName][token];
    }
}
