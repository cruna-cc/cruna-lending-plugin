# LendingCrunaPlugin README

## Overview
The LendingCrunaPlugin, part of the Cruna Protocol ecosystem, enables secure and controlled lending of digital assets. It allows projects to lend out assets under specific conditions, ensuring assets are utilized for intended purposes such as beta testing, without the risk of premature withdrawal or sale.

## Key Features
- **Secure Asset Lending**: Lock assets for a specified minimum lending period, preventing premature withdrawals.
- **Depositor Control**: Allows the asset depositor to retain control over their assets, with options to withdraw to the original address or transfer to another validated plugin after the lending period.
- **Beta Tester Restrictions**: Ensures beta testers can use the assets without the ability to withdraw or sell them, focusing on testing purposes.
- **Flexible and Extensible**: Seamlessly integrates with the Cruna Protocol, supporting various digital assets and lending conditions.

## Getting Started

### Prerequisites for depositors
- Work with a project that has deployed a Vault contract using the Cruna Protocol.
- Understand the Lending Plugin SDK and install it from here <Link to follow>.

### Prerequisites for borrowers
- Buy a Vault contract using the Cruna Protocol.
- Activate the LendingCrunaPlugin on the dashboard.
- Copy the plugin address and give it to a potential depositor project.

### Functionality for Depositors
There are functions that you will use to deposit and withdraw assets.

The main functions are:

Deposits an asset into the Vault for lending.
```
function depositAsset(address assetAddress, uint256 tokenId, address stableCoin)
```

Withdraws an asset from the Vault after the lending period.
```
function withdrawAsset(address assetAddress, uint256 tokenId, address withdrawTo)
```

Transfers an asset to another plugin after the lending period.
```
  function transferAssetToPlugin(address assetAddress,uint256 tokenId_,uint256 toVaultTokenId,address stableCoin)
```

Rescind ownership of the asset to the Vault owner
```
function rescindOwnership(address assetAddress, uint256 tokenId)
```

## License Agreement for LendingCrunaPlugin

Copyright (C) 2024-present Cruna

All rights reserved.

This software and associated documentation files (the "Software") are provided for personal, non-commercial use only. You may not use this code except in compliance with this License. You may obtain a copy of the License by reviewing this file or requesting a copy from the copyright holder.

Restrictions:
- You may not use the Software for commercial purposes without obtaining a license from the copyright holder.
- You may not distribute, sublicense, or sell copies of the Software.
- You may not modify, merge, publish, distribute, sublicense, and/or sell copies of the Software for commercial purposes.

The Software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
