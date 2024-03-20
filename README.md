# LendingCrunaPlugin

The LendingCrunaPlugin is an extension for the [Cruna Protocol](https://github.com/crunaprotocol/cruna-protocol/blob/main/README.md), designed to enable secure and controlled lending of digital assets. It allows projects to lend out assets under specific conditions, ensuring assets are utilized for intended purposes such as beta testing, without the risk of premature withdrawal or sale.

## Features

- **Secure Asset Lending**: Lock assets for a specified minimum lending period, preventing premature withdrawals.
- **Depositor Control**: Allows the asset depositor (e.g., MayG) to retain control over their assets, with options to withdraw to the original address or transfer to another validated plugin after the lending period.
- **Beta Tester Restrictions**: Ensures beta testers can use the assets without the ability to withdraw or sell them, focusing on testing purposes.
- **Flexible and Extensible**: Seamlessly integrates with the Cruna Protocol, supporting various digital assets and lending conditions.

## Getting Started

To integrate the LendingCrunaPlugin with your TRTVault, follow these steps:

### Prerequisites

- Deployed CrunaVault using the Cruna Protocol.
- Cruna Protocol SDK installed.

### Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/yourrepository/LendingCrunaPlugin.git
   ```

2. Install dependencies:
   ```sh
   npm install
   ```

### Setting Up the Plugin

1. Plug the LendingCrunaPlugin into your TRTVault:
   ```javascript
   // Example code snippet
   const vault = await CrunaVault.deploy();
   await vault.plug("LendingCrunaPlugin", LendingCrunaPlugin.address);
   ```

2. Configure the plugin with your lending rules:
   ```javascript
   // Set lending rules - example
   await lendingCrunaPlugin.setLendingRulesAddress(lendingRules.address);
   ```

## Usage

### For Depositors

1. Deposit assets into a beta tester's plugin address:
   ```javascript
   // Deposit an asset
   await lendingCrunaPlugin.depositAsset(assetAddress, tokenId, stableCoinAddress);
   ```

2. Withdraw or transfer assets after the lending period:
   ```javascript
   // Withdraw to the original depositor address
   await lendingCrunaPlugin.withdrawAsset(assetAddress, tokenId, depositorAddress);
   
   // Or transfer to another validated plugin
   await lendingCrunaPlugin.transferAssetToPlugin(assetAddress, tokenId, toVaultTokenId, stableCoinAddress);
   ```
3. Utilize the SDK developed by TRT to monitor and identify which gamers currently hold your assets. This powerful tool enables Depositors to have real-time insights into asset distribution, ensuring a transparent and controlled testing environment.
   ```javascript
   // Example usage of the TRT SDK for asset tracking
   const assetOwnershipDetails = await trtSdk.getAssetOwnership(assetId);
   console.log(`Asset is currently held by: ${assetOwnershipDetails.rightsHolderAddress}`);
   ```

This SDK functionality not only enhances the management of lent assets but also fosters trust between Depositors and beta testers by providing a transparent overview of asset usage.


## License

This project is licensed under the [GPL-3.0 License](LICENSE).
```
