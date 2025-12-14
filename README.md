## Audit Report
![Screenshot](https://github.com/AidenNabavi/Harvest/raw/main/test/Screenshot%20.png)
Project:`Harvest Finance`  
Researcher:`Aiden`
Date:`2025/12/14`

---


## Title 

**Temporary freezing of funds via Dos on emergencyExit**

---

##  Report Type

`Smart Contract`
`On-chain`
`Staking`
`Yield Farming`


---

##  Target 
- `Address`:  https://github.com/harvestfi/harvest-strategy-arbitrum/blob/master/contracts/strategies/venus/VenusFoldStrategy.sol

- `Asset`:  VenusFoldStrategy.sol

- `Function(s)`:     emergencyExit()          called👉🏽         _withdrawMaximum()        called👉🏽          _redeemMaximum()


## Summary

there is an issue  in  `VenusFoldStrategy.sol` contract, which can cause a `temporary freezing of funds`. The issue occurs when the `emergencyExit` function is called by Governance while the `pendingFee` value is high. In this case,
`pendingFee does not decrease`.because there is no mechanism like `_handleFee` function  to decrease pending fee.

As a result, the full withdrawal operation (_redeemMaximum) will revert, making the funds temporarily inaccessible. The function cannot be executed again until the pendingFee is reduced.

---
## Rating

Severity: `High`

Impact: `High`

Likelihood:`Low` 

Attack Complexity :`Low`


---
## Analysis

- ``Preconditions for the bug:``  just The borrower’s volume must be high. 
- ``Bug triggered by:`` Governance   
- ``Amount at risk:`` Can be either large or small, depending on when the `emergencyExit` function is called.  
- ``Who is affected (users, protocol, etc.):`` Primarily the protocol; users may also be indirectly affected.  
- ``Impact:`` This function is meant for emergency situations to quickly withdraw funds. If `emergencyExit` is called under the conditions that trigger this issue, it can temporarily freeze funds, potentially causing significant disruption. This is critical because the function’s purpose is rapid fund retrieval in emergencies.  




---
## Description

**Explain Contract/Function First**
the `VenusFoldStrategy.sol` contract is a yield farming strategy that interacts with the Venus platform by supplying and borrowing assets. 
the `emergencyExit()` function is designed for emergency scenarios to quickly withdraw all investor funds and protect them from potential risks.

**Vulnerability**


this issue occurs when the `emergencyExit()` function is called by Governance:

1. `emergencyExit()` calls the `_withdrawMaximum()` function.
2. `_withdrawMaximum()` executes `_accrueFee()`, which increases the `pendingFee`.
3. The `_handleFee()` function, which normally  reduces or resets  `pendingFee`, is **skipped**.
4. `_redeemMaximum()` is then executed to withdraw all assets:

```solidity
   balance = supplied - borrowed - pendingFee
```
5. since `pendingFee` is still high, the withdrawable balance becomes negative, causing an  underflow .
6. result: The transaction reverts and funds become temporarily inaccessible (DoS).


---
##  Vulnerability Details


```solidity 



function emergencyExit() external onlyGovernance {
    _withdrawMaximum(false);
    _setPausedInvesting(true);
    _updateStoredBalance();
}




//next👇🏽


//🚩 if this input equals false, _handleFee() is NOT executed decrease pending fee,
// that's why pendingFee becomes large
// Why is this a problem?
// Go to _redeemMaximum() 
function _withdrawMaximum(bool claim) internal {
    if (claim) {
        _handleFee();         // Accrues and resets pending fees
        _claimReward();       // Claims rewards
        _liquidateReward();   // Converts rewards to underlying
    } else {
        _accrueFee();         // Only accrues fees, does NOT reset pendingFee
    }

    // Attempt to redeem all underlying; can revert if pendingFee is too high
    _redeemMaximum();
}





//next👇🏽

  function _accrueFee() internal {
    uint256 fee;
    if (currentBalance() > storedBalance()) {
      uint256 balanceIncrease = currentBalance().sub(storedBalance());
      fee = balanceIncrease.mul(totalFeeNumerator()).div(feeDenominator());
    }
    setUint256(_PENDING_FEE_SLOT, pendingFee().add(fee));
    _updateStoredBalance();
  }






//next👇🏽


// As mentioned above, the only condition for this vulnerability to occur:
// the borrower's volume must be high. -->and this can happen quite frequently in practice.


function _redeemMaximum() internal {
    address _cToken = cToken();
    uint256 available = CTokenInterface(_cToken).getCash();

    // Amount we supplied
    uint256 supplied = CTokenInterface(_cToken).balanceOfUnderlying(address(this));
    // Amount we borrowed
    uint256 borrowed = CTokenInterface(_cToken).borrowBalanceCurrent(address(this));


    
    // But when pendingFee is not reset, it becomes large.
    // If this function is called when borrow amounts are high, balance --->  underflow and revert.
    //example👇🏽
    // 10000*1e18- 9500*1e18 - 501*1e18         -----> revert
    uint256 balance = supplied.sub(borrowed).sub(pendingFee());🚩

    _redeemWithFlashloan(Math.min(balance, available), 0);

    available = CTokenInterface(_cToken).getCash();
    supplied = CTokenInterface(_cToken).balanceOfUnderlying(address(this));

    // Redeem any remaining amount above pendingFee
    if (Math.min(supplied, available) > pendingFee()) {
        _redeem(Math.min(supplied, available).sub(pendingFee().add(1)));
    }
}

```




---
## How to fix it (Recommended)

The recommended fix is to ensure that `pendingFee` is properly reset when `emergencyExit()` is called. 
This can be done by calling `_handleFee()` even when `claim` is `false`, or by creating a dedicated reset function for `pendingFee`. 

Example fix:

```solidity
function emergencyExit() external onlyGovernance {
    _handleFee();               // Ensure pendingFee is accrued and reset
    _withdrawMaximum(true);     // Pass true to handle fees and claim rewards safely
    _setPausedInvesting(true);
    _updateStoredBalance();
}

// Alternatively, modify _withdrawMaximum to always reset pendingFee:
function _withdrawMaximum(bool claim) internal {
    _handleFee();               // Always accrue and reset pendingFee
    if (claim) {
        _claimReward();
        _liquidateReward();
    }
    _redeemMaximum();
}

```
---

##  References

* https://github.com/harvestfi/harvest-strategy-arbitrum

* https://github.com/harvestfi/harvest-strategy-arbitrum/blob/master/contracts/strategies/venus/VenusFoldStrategy.sol

* VenusFoldStrategy.sol

---
##  Proof of Concept (PoC)

Several separate  bad design flows(RedFlag) exist, which you can review at the following Gist address:👇🏽
`https://gist.github.com/AidenNabavi/f81ec078bc0474a745a00c9100440926`

**Step by Step**

for run test downlaod zip file from 👇🏽
``

use this for test
`forge  test  main.sol -vvvvv`


```solidity 

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/contracts/venus/VenusFoldStrategy.sol";

/*

NOTE ABOUT INITIALIZATION
-------------------------------------------------------------------------------
The following check in      Initializable.sol     was commented out intentionally:

require(
    (isTopLevelCall && _initialized < 1) ||
    (!Address.isContract(address(this)) && _initialized == 1),
    "Initializable: contract is already initialized"
);

This was done ONLY for testing purposes to allow multiple initializations.
This does NOT reflect production behavior.

*/


//mock cToken
contract CToken {
    string public name = "CToken";
    string public symbol = "CT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function getCash() external view returns (uint256) {
        return 0;
    }

    //   Supplied: 10,000
    function balanceOfUnderlying(address) external pure returns (uint256) {
        return 10_000 * 1e18; // supplied
    }

    //   Borrowed: 9,500
    function borrowBalanceCurrent(address) external pure returns (uint256) {
        return 9_500 * 1e18; // borrowed
    }

    function underlying() external pure returns (address) {
        return address(0x00222222);
    }
}




//Required for market entry during initialization

contract ComptrollerMock {
    function enterMarkets(address[] memory cTokens)
        external
        pure
        returns (uint[] memory)
    {
        uint[] memory results = new uint[](cTokens.length);
        for (uint i = 0; i < cTokens.length; i++) {
            results[i] = 0;
        }
        return results;
    }
}


//Defines fee configuration used by VenusFoldStrategy

contract ControllerMock {

    function platformFeeNumerator() public pure returns (uint256) {
        return 300; // 3% platform fee
    }

    function strategistFeeNumerator() public pure returns (uint256) {
        return 200; // 2% strategist fee
    }

    function profitSharingNumerator() public pure returns (uint256) {
        return 500; // 5% profit sharing
    }

    function feeDenominator() public pure returns (uint256) {
        return 10_000; // basis points
    }
}






// Test Contract

contract Main is Test {
    VenusFoldStrategy strategy;

    CToken ct;
    ComptrollerMock comptroller;
    ControllerMock controller;

    address governance = address(0x000045);

    function setUp() public {
        ct = new CToken(100_000_000 * 1e18);
        comptroller = new ComptrollerMock();
        controller = new ControllerMock();



        // Deploy Storage and configure governance/controller
        Storage store = new Storage();
        store.setGovernance(governance);
        vm.prank(governance);
        store.setController(address(controller));




        // Deploy and initialize strategy
        strategy = new VenusFoldStrategy();
        strategy.initializeBaseStrategy(
            address(store),
            address(0x00222222),
            address(0x00003333),
            address(ct),
            address(comptroller),
            address(0x00778899),
            1000,
            2000,
            3000,
            true
        );



   
        /*
        /// NOTE:
        In this test, this values are set directly to storage because following the full contract flow
        would make the test noisy and unnecessarily complex.
        If a test using the complete natural execution flow of the contract is required,
        you can mention it in the Immunefi report comments _ and I will prepare it as soon as possible.
        */
        vm.store(address(strategy),strategy._STORED_SUPPLIED_SLOT(),bytes32(uint256(400 * 1e18)));
        vm.store(address(strategy),strategy._PENDING_FEE_SLOT(),bytes32(uint256(501 * 1e18)));
    }


/*
===============================================================================
IMPORTANT OBSERVATIONS

- _accrueFee()    increase   pendingFee
- _handleFee()  reduse  pendingFee 
- emergencyExit()    calls _accrueFee()        but SKIPS     _handleFee()
- This allows pendingFee to exceed withdrawable balance
- Result: arithmetic underflow and permanent DoS

flow 👉🏽 emergencyExit()👉🏽_withdrawMaximum()👉🏽 _accrueFee() 👉🏽_redeemMaximum()👉🏽 supplied - borrowed - pendingFee
===============================================================================
*/

    function test_Dos() public {
        vm.startPrank(governance);

        uint256 currentBalance = strategy.currentBalance();
        console.log("current balance ------------------------>", currentBalance);
        // supplied (10000) - borrowed (9500) = 500

        uint256 pending = strategy.pendingFee();
        console.log("pendingFee------------------------------>", pending);
        // pendingFee = 501

        uint256 storedBalance = strategy.storedBalance();
        console.log("storedBalance ------------------------>", storedBalance);
        // storedBalance = 400

        /*
        Underflow occurs here:

        supplied - borrowed - pendingFee
        10000e18 - 9500e18 - 501e18 = -1e18  --> revert
        */

        vm.expectRevert(stdError.arithmeticError);//POC
        strategy.emergencyExit();

        vm.stopPrank();
    }
}

    
```








