pragma solidity 0.8.3;

contract StaticCaller {
    function staticCall(address target, bytes memory data) internal view returns (bool result) {
        assembly {
            result := staticcall(gas(), target, add(data, 0x20), mload(data), mload(0x40), 0)
        }
        return result;
    }

    function staticCallUint256(address target, bytes memory data) internal view returns (uint256 ret) {
        bool result;
        assembly {
            let size := 0x20
            let free := mload(0x40)
            result := staticcall(gas(), target, add(data, 0x20), mload(data), free, size)
            ret := mload(free)
        }
        require(result, "STATIC_CALLER/FAILED");
        return ret;
    }
}
