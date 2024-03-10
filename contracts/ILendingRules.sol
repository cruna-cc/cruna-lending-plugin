// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

interface ILendingRules {
  function getDepositorConfig(address depositor) external view returns (uint256 depositFee, address nftContractAddress);
  function getTreasuryWallet() external view returns (address);
}
