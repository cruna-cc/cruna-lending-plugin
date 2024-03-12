// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

interface ILendingRules {
  function getDepositFee(address nftContractAddress) external view returns (uint256);
  function getTreasuryWallet() external view returns (address);
  function setDefaultDepositFee(uint256 defaultDepositFee) external;
  function setSpecialDepositFee(address nftContractAddress, uint256 depositFee) external;
  function setTreasuryWallet(address newTreasuryWallet) external;
}
