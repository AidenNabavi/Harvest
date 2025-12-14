// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/contracts/base/Drip.sol";



contract DesignFlow is Test {
    Drip drip_;

       address governance=address(0x000045);

    function setUp() public {

        Storage store = new Storage();
        store.setGovernance(governance); 
        
        drip_=new Drip(address(store));
 
            vm.startPrank(governance);
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x010101010101),100); //index 0
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x1),1000);//index 1
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x2),2000);//index 2   // this will be deleted
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x3),3000);//index 3
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x4),4000);//index 4
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x5),5000);//index 5    // this will be deleted
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x6),6000);//index 6
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x7),7000);//index 7
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x8),8000);//index 8    // this will be deleted
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x9),9000);//index 9   
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x10),10000);//index10   // this will be deleted
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x11),11000);//index11
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x12),12000);//index12   
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x13),13000);//index13     // this will be deleted
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x14),14000);//index14   
        drip_.addDrip(Drip.DripMode.TokenAmount,address(0x15),15000);//index15
            vm.stopPrank();

    }

    ///@notice In the output of this test, you can see that the indices have changed for each drip
    function test_removeIndexShift() public {
            vm.startPrank(governance);

        // حذف چند ایندکس
        drip_.removeDrip(2);
        drip_.removeDrip(13);
        drip_.removeDrip(8);
        drip_.removeDrip(10);
        drip_.removeDrip(5);
            vm.stopPrank();

        for (uint256 i = 0; i < 11; i++) {
            (
                Drip.DripMode mode,
                address vault,
                uint256 perSecond,
                uint256 lastDripTime
            ) = drip_.drips(i);

            console.log("index :", i);
            console.log("vault:", vault);
            console.log("_____________");


        }
    }

}

