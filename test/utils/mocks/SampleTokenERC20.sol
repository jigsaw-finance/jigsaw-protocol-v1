// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleTokenERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function getTokens(
        uint256 _val
    ) external {
        _mint(msg.sender, _val);
    }

    function getTokensTo(uint256 _val, address _receiver) external {
        _mint(_receiver, _val);
    }
}
