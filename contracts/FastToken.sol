// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./Channel.sol";

contract FastToken is Channel, Ownable {
    // Constructor
    constructor(
        string memory ERC20name,
        string memory ERC20symbol,
        string memory EIP712name,
        string memory EIP712version
    )
        ERC20(ERC20name, ERC20symbol)
        EIP712(EIP712name, EIP712version)
        Ownable(msg.sender)
    {}

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
