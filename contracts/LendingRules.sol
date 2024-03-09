// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRules is Ownable {
  error TreasuryWalletZeroAddress();
  error InvalidAddress();
  error InvalidFees();

  struct DepositFee {
    uint256 depositFee; // Fee for depositing assets by each project/depositor
  }

  uint256 private _activationFee; // Global activation fee for using the plugin
  mapping(address => DepositFee) private _feesMapping; // Mapping to store deposit fees for each project/depositor
  address private _treasuryWallet; // Treasury wallet address

  event DepositFeeSet(address indexed depositor, uint256 depositFee);
  event ActivationFeeSet(uint256 activationFee);
  event TreasuryWalletUpdated(address newTreasuryWallet);

  constructor(address initialOwner, address treasuryWallet, uint256 activationFee) Ownable(initialOwner) {
    setTreasuryWallet(treasuryWallet);
    setActivationFee(activationFee);
  }

  function setDepositFee(address depositor, uint256 depositFee) public onlyOwner {
    if (depositor == address(0)) revert InvalidAddress();
    _feesMapping[depositor] = DepositFee(depositFee);
    emit DepositFeeSet(depositor, depositFee);
  }

  function setActivationFee(uint256 activationFee) public onlyOwner {
    _activationFee = activationFee;
    emit ActivationFeeSet(activationFee);
  }

  function setTreasuryWallet(address newTreasuryWallet) public onlyOwner {
    if (newTreasuryWallet == address(0)) revert TreasuryWalletZeroAddress();
    _treasuryWallet = newTreasuryWallet;
    emit TreasuryWalletUpdated(newTreasuryWallet);
  }

  function getDepositFee(address depositor) public view returns (uint256) {
    return _feesMapping[depositor].depositFee;
  }

  function getActivationFee() public view returns (uint256) {
    return _activationFee;
  }

  function getTreasuryWallet() public view returns (address) {
    return _treasuryWallet;
  }
}
