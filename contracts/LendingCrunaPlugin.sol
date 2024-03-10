// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ILendingRules.sol";

contract LendingCrunaPlugin is LendingCrunaPluginBase {
  error InsufficientDepositFee(uint256 requiredFee, uint256 providedFee);

  mapping(address => mapping(uint256 => address)) private _depositedAssets;

  ILendingRules public lendingRules;

  constructor(address _lendingRulesAddress) {
    lendingRules = ILendingRules(_lendingRulesAddress);
  }

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  // Function to handle the deposit of an ERC721 token
  function depositAsset(address assetAddress, uint256 tokenId) public payable {
    // Retrieve the deposit fee for the sender from the LendingRules contract
    uint256 depositFee = lendingRules.getDepositFee(msg.sender);

    if (msg.value < depositFee) {
      revert InsufficientDepositFee({requiredFee: depositFee, providedFee: msg.value});
    }

    // Transfer the asset
    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);
    require(IERC721(assetAddress).ownerOf(tokenId) == address(this), "Transfer failed");

    // Store the asset depositor
    _depositedAssets[assetAddress][tokenId] = msg.sender;

    // Only transfer the deposit fee if it's greater than 0
    if (depositFee > 0) {
      address treasuryWallet = lendingRules.getTreasuryWallet();
      payable(treasuryWallet).transfer(depositFee);
    }

    // Emit an event
    emit AssetReceived(assetAddress, tokenId, msg.sender, block.timestamp);
  }

  // Function to handle the withdrawal of a deposited ERC721 token
  function withdrawAsset(address assetAddress, uint256 tokenId) public {
    require(_depositedAssets[assetAddress][tokenId] == msg.sender, "Caller is not the depositor");
    _depositedAssets[assetAddress][tokenId] = address(0);
    IERC721(assetAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    emit AssetWithdrawn(assetAddress, tokenId, msg.sender, block.timestamp);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
