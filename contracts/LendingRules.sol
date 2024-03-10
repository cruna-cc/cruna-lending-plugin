// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRules is Ownable {
  error TreasuryWalletZeroAddress();
  error InvalidAddress();
  error InvalidFees();

  struct DepositorConfig {
    uint256 depositFee; // Fee for depositing assets by each project/depositor
    address nftContractAddress; // NFT contract address associated with the depositor
  }

  uint256 private _activationFee; // Global activation fee for using the plugin
  mapping(address => DepositorConfig) private _depositorConfigs; // Mapping to store config for each project/depositor
  address private _treasuryWallet; // Treasury wallet address

  event DepositorConfigSet(address indexed depositor, uint256 depositFee, address nftContractAddress);
  event ActivationFeeSet(uint256 activationFee);
  event TreasuryWalletUpdated(address newTreasuryWallet);

  constructor(address initialOwner, address treasuryWallet, uint256 activationFee) Ownable(initialOwner) {
    setTreasuryWallet(treasuryWallet);
    setActivationFee(activationFee);
  }

  function setDepositorConfig(address depositor, uint256 depositFee, address nftContractAddress) public onlyOwner {
    require(depositor != address(0) && nftContractAddress != address(0), "InvalidAddress");
    _depositorConfigs[depositor] = DepositorConfig(depositFee, nftContractAddress);
    emit DepositorConfigSet(depositor, depositFee, nftContractAddress);
  }

  function setActivationFee(uint256 activationFee) public onlyOwner {
    _activationFee = activationFee;
    emit ActivationFeeSet(activationFee);
  }

  function setTreasuryWallet(address newTreasuryWallet) public onlyOwner {
    require(newTreasuryWallet != address(0), "TreasuryWalletZeroAddress");
    _treasuryWallet = newTreasuryWallet;
    emit TreasuryWalletUpdated(newTreasuryWallet);
  }

  function getDepositorConfig(address depositor) public view returns (uint256, address) {
    return (_depositorConfigs[depositor].depositFee, _depositorConfigs[depositor].nftContractAddress);
  }

  function getActivationFee() public view returns (uint256) {
    return _activationFee;
  }

  function getTreasuryWallet() public view returns (address) {
    return _treasuryWallet;
  }
}
