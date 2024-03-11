// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILendingRules.sol";

import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";

contract LendingCrunaPlugin is LendingCrunaPluginBase {
  error InsufficientDepositFee(uint256 requiredFee, uint256 providedFee);
  error InsufficientFunds();
  error TransferFailed();
  error InvalidLendingRulesAddress();
  error NotDepositor(address caller, address expected);
  error TransferToTreasuryFailed();

  mapping(address => mapping(uint256 => address)) private _depositedAssets;

  ILendingRules public lendingRules;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  // TODO This should be only updated by the owner
  function setLendingRules(address _lendingRulesAddress) external {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRules = ILendingRules(_lendingRulesAddress);
  }

  // Function to handle the deposit of an ERC721 token
  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    // Correctly calling getDepositFee to check for special pricing or default fee
    uint256 depositFee = lendingRules.getDepositFee(assetAddress);

    if (IERC20(stableCoin).balanceOf(msg.sender) < depositFee) {
      revert InsufficientFunds();
    }

    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);
    require(IERC721(assetAddress).ownerOf(tokenId) == address(this), "Transfer failed");

    _depositedAssets[assetAddress][tokenId] = msg.sender;

    if (depositFee > 0) {
      address treasuryWallet = lendingRules.getTreasuryWallet();
      bool success = IERC20(stableCoin).transferFrom(msg.sender, treasuryWallet, depositFee);
      if (!success) {
        revert TransferToTreasuryFailed();
      }
    }

    emit AssetReceived(assetAddress, tokenId, msg.sender);
  }

  function withdrawAsset(address assetAddress, uint256 tokenId) public {
    if (_depositedAssets[assetAddress][tokenId] != msg.sender) {
      revert NotDepositor(msg.sender, _depositedAssets[assetAddress][tokenId]);
    }
    _depositedAssets[assetAddress][tokenId] = address(0);
    IERC721(assetAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    emit AssetWithdrawn(assetAddress, tokenId, msg.sender);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
