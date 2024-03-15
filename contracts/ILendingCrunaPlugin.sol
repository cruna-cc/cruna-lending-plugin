// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ILendingCrunaPlugin
 * @dev Interface for LendingCrunaPlugin contracts
 */
interface ILendingCrunaPlugin is IERC165 {
  function depositFromPlugin(address assetAddress, uint256 tokenId, address fromPlugin, address stableCoin) external;
}
