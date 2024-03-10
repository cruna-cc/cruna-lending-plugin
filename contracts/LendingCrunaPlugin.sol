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

  mapping(address => mapping(uint256 => address)) private _depositedAssets;

  ILendingRules public lendingRules;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  // Remove lendingRules initialization from the constructor
  // and add a setter method for it
  function setLendingRules(address _lendingRulesAddress) external {
    require(_lendingRulesAddress != address(0), "Invalid address");
    lendingRules = ILendingRules(_lendingRulesAddress);
  }

  // Function to handle the deposit of an ERC721 token
  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    (uint256 depositFee, ) = lendingRules.getDepositorConfig(msg.sender);

    if (IERC20(stableCoin).balanceOf(msg.sender) < depositFee) {
      revert InsufficientFunds();
    }

    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);
    require(IERC721(assetAddress).ownerOf(tokenId) == address(this), "Transfer failed");

    _depositedAssets[assetAddress][tokenId] = msg.sender;

    if (depositFee > 0) {
      address treasuryWallet = lendingRules.getTreasuryWallet();
      bool success = IERC20(stableCoin).transferFrom(msg.sender, treasuryWallet, depositFee);
      require(success, "Failed to transfer deposit fee to treasury.");
    }

    emit AssetReceived(assetAddress, tokenId, msg.sender);
  }

  function withdrawAsset(address assetAddress, uint256 tokenId) public {
    require(_depositedAssets[assetAddress][tokenId] == msg.sender, "Caller is not the depositor");
    _depositedAssets[assetAddress][tokenId] = address(0);
    IERC721(assetAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    emit AssetWithdrawn(assetAddress, tokenId, msg.sender, block.timestamp);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
