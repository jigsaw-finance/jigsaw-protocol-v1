// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JigsawPoints is ERC20 {
    constructor() ERC20("Jigsaw Point", "JSP") {
        _mint(msg.sender, 1_000_000 * 10**18);
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
