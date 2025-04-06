// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract matchToken is ERC20, Ownable, ERC20Burnable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, 20000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(
            amount > 0 && amount <= 10000,
            "range require 0 <amount <=10000 one time"
        );
        amount = amount * 10 ** decimals(); //
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        address owner = msg.sender;
        require(balanceOf(owner) >= value, "ERC20: insufficient balance");
        _approve(owner, spender, value);
        return true;
    }
}
