// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UsdcToken is ERC20 {
    constructor(uint256 intialSupply) ERC20("USDCToken", "USDC") {
        _mint(msg.sender, intialSupply);
    }
}

contract HdToken is ERC20 {
    constructor(uint256 intialSupply) ERC20("HDToken", "HD") {
        _mint(msg.sender, intialSupply);
    }
}
