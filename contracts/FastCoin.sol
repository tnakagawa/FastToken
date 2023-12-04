// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./Channel.sol";

contract FastCoin is Channel {
    // Constructor
    constructor(
        string memory ERC20name,
        string memory ERC20symbol,
        string memory EIP712name,
        string memory EIP712version
    ) ERC20(ERC20name, ERC20symbol) EIP712(EIP712name, EIP712version) {}

    function deposit() public payable {
        if (msg.value > 0) {
            _mint(_msgSender(), msg.value);
        }
    }

    function withdraw(uint256 amount) public payable {
        if (amount > 0) {
            _burn(_msgSender(), amount);
            payable(_msgSender()).transfer(amount);
        }
    }
}
