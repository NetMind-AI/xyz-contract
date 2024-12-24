// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ;

interface IProxyAdmin {
    function changeProxyAdmin(address proxy, address newAdmin) external;
    function upgrade(address proxy, address implementation) external;
    function transferOwnership(address newOwner) external;
}

interface IManagement {
    function addNodePropose(address _addr) external;
    function deleteNodePropose(address _addr) external;
    function updateTransparentProxyAdminPropose(address _proxyAdmin, address _transparentProxy, address _addr) external;
    function updateTransparentProxyUpgradPropose(address _proxyAdmin, address _transparentProxy, address _addr) external;
    function updateAdminOwnerPropose(address _proxyAdmin, address _newOwner) external;
    function excContractPropose(address _transparentProxy, bytes memory _data) external;
    function excContractProposes(address[] calldata _transparentProxys, bytes[] calldata _datas) external;
    function vote(uint256 _proposalId) external;
    function votes(uint256[] calldata _proposalIds) external;

}

contract Management is IManagement{
    uint256 public  proposalCount;
    mapping(uint256 => ProposalMsg) public proposalMsg;
    uint256 public nodeNum;
    mapping(address => uint256) nodeAddrIndex;
    mapping(uint256 => address) nodeIndexAddr;
    mapping(address => bool) public nodeAddrSta;
    bool private reentrancyLock = false;
    enum TypeIndex{AddNodeAddr, DeleteNodeAddr, ChangeAdmin, Upgrade, UpdateAdminOwner, ExcContract}

    event Propose(address indexed proposer, uint256 proposalId, string label);
    event Vote(address indexed voter, uint256 proposalId);

    struct ProposalMsg {
        address[] proposers;
        bool proposalSta;
        IProxyAdmin proxyAdmin;
        address transparentProxy;
        address addr;
        bytes data;
		uint256 expire;
        TypeIndex typeIndex;
        string  label;
        mapping(address => bool) voterSta;
    }

    modifier nonReentrant() {
        require(!reentrancyLock);
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    constructor(address[] memory _nodeAddrs) {
        require( _nodeAddrs.length> 4,"less than 5");
        for (uint256 i = 0; i< _nodeAddrs.length; i++){
            addNodeAddr(_nodeAddrs[i]);
        }
    }

    function addNodePropose(address _addr) override external{
        require(_addr != address(0), "0 address");
        require(!nodeAddrSta[_addr], "node address error");
        bytes memory data = new bytes(0x00);
        _propose(address(0), address(0), _addr, data, TypeIndex.AddNodeAddr, "addNode");
    }

    function deleteNodePropose(address _addr) override external{
        require(nodeAddrSta[_addr], "node error");
        require(nodeNum > 5, "less than 5");
        _propose(address(0), address(0), _addr, new bytes(0x00), TypeIndex.DeleteNodeAddr, "deleteNode");
    }

    function updateTransparentProxyAdminPropose(address _proxyAdmin, address _transparentProxy, address _addr) override external{
        _propose(_proxyAdmin, _transparentProxy, _addr, new bytes(0x00), TypeIndex.ChangeAdmin, "updateTransparentProxyAdminPropose");
    }

    function updateTransparentProxyUpgradPropose(address _proxyAdmin, address _transparentProxy, address _addr) override external{
        _propose(_proxyAdmin, _transparentProxy, _addr, new bytes(0x00), TypeIndex.Upgrade, "updateTransparentProxyUpgradPropose");
    }

    function updateAdminOwnerPropose(address _proxyAdmin, address _newOwner) override external{
        _propose(_proxyAdmin, address(0), _newOwner, new bytes(0x00), TypeIndex.UpdateAdminOwner, "updateAdminOwnerPropose");
    }

    function excContractProposes(address[] calldata _transparentProxys, bytes[] calldata _datas) override external{
        for(uint i=0; i<_transparentProxys.length; i++){
            _excContractPropose(_transparentProxys[i], _datas[i]);
        }
    }

    function excContractPropose(address _transparentProxy, bytes memory _data) override external{
        _excContractPropose(_transparentProxy, _data);
    }

    function _excContractPropose(address _transparentProxy, bytes memory _data) internal{
        _propose(address(0), _transparentProxy, address(0), _data, TypeIndex.ExcContract, "excContract");
    }

    function _propose(
        address _proxyAdmin,
        address _transparentProxy,
        address _addr,
        bytes memory _data,
        TypeIndex _typeIndex,
        string memory _label
    ) internal{
        address _sender = msg.sender;
        require(nodeAddrSta[_sender], "not nodeAddr");
        uint256 _time = block.timestamp;
        uint256 _proposalId = ++proposalCount;
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        _proposalMsg.proposers.push(_sender);
        _proposalMsg.proxyAdmin = IProxyAdmin(_proxyAdmin);
        _proposalMsg.transparentProxy = _transparentProxy;
        _proposalMsg.addr = _addr;
        _proposalMsg.data = _data;
        _proposalMsg.expire = _time + 86400*3;
        _proposalMsg.typeIndex = _typeIndex;
        _proposalMsg.label = _label;
        _proposalMsg.voterSta[_sender] = true;
        emit Propose(_sender, _proposalId, _label);
    }

    function vote(uint256 _proposalId) override external nonReentrant(){
        _vote(_proposalId);
    }

    function votes(uint256[] calldata _proposalIds) override external nonReentrant(){
        for(uint i=0; i<_proposalIds.length; i++){
            _vote(_proposalIds[i]);
        }
    }

    function _vote(uint256 _proposalId) internal {
        address _sender = msg.sender;
        require(nodeAddrSta[_sender], "not nodeAddr");
        uint256 _time = block.timestamp;
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        require(!_proposalMsg.proposalSta, "proposal executed");
        require(_proposalMsg.expire > _time, "proposal expired");
        require(!_proposalMsg.voterSta[_sender], "proposer voted");
        _proposalMsg.proposers.push(_sender);
        _proposalMsg.voterSta[_sender] = true;
        uint256 length = _proposalMsg.proposers.length;
        if(length> nodeNum/2 && !_proposalMsg.proposalSta){
            require(_actuator(_proposalId), "call failed");
            _proposalMsg.proposalSta = true;
        }
        emit Vote(_sender, _proposalId);
    }

    function _actuator(uint256 _proposalId) internal returns(bool){
        bool result = false;
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        TypeIndex _typeIndex = _proposalMsg.typeIndex;
        if(_typeIndex == TypeIndex.AddNodeAddr){
            addNodeAddr(_proposalMsg.addr);
            result = true;
        }else if(_typeIndex == TypeIndex.DeleteNodeAddr){
            deleteNodeAddr(_proposalMsg.addr);
            result = true;
        }else if(_typeIndex == TypeIndex.ChangeAdmin){
            _proposalMsg.proxyAdmin.changeProxyAdmin(_proposalMsg.transparentProxy, _proposalMsg.addr);
            result = true;
        }else if(_typeIndex == TypeIndex.Upgrade){
            _proposalMsg.proxyAdmin.upgrade(_proposalMsg.transparentProxy, _proposalMsg.addr);
            result = true;
        }else if(_typeIndex == TypeIndex.UpdateAdminOwner){
            _proposalMsg.proxyAdmin.transferOwnership(_proposalMsg.addr);
            result = true;
        }else if(_typeIndex == TypeIndex.ExcContract){
            bytes memory _data = _proposalMsg.data;
            (result, ) = _proposalMsg.transparentProxy.call(_data);
        }
        return result;
    }

    function addNodeAddr(address _nodeAddr) internal{
        require(_nodeAddr != address(0), "0 address");
        require(!nodeAddrSta[_nodeAddr], "node address error");
        nodeAddrSta[_nodeAddr] = true;
        uint256 _nodeAddrIndex = nodeAddrIndex[_nodeAddr];
        if (_nodeAddrIndex == 0){
            _nodeAddrIndex = ++nodeNum;
            nodeAddrIndex[_nodeAddr] = _nodeAddrIndex;
            nodeIndexAddr[_nodeAddrIndex] = _nodeAddr;
        }
    }

    function deleteNodeAddr(address _nodeAddr) internal{
        require(nodeAddrSta[_nodeAddr], "node error");
        nodeAddrSta[_nodeAddr] = false;
        uint256 _nodeAddrIndex = nodeAddrIndex[_nodeAddr];
        if (_nodeAddrIndex > 0){
            uint256 _nodeNum = nodeNum;
            address _lastNodeAddr = nodeIndexAddr[_nodeNum];
            nodeAddrIndex[_lastNodeAddr] = _nodeAddrIndex;
            nodeIndexAddr[_nodeAddrIndex] = _lastNodeAddr;
            nodeAddrIndex[_nodeAddr] = 0;
            nodeIndexAddr[_nodeNum] = address(0x0);
            nodeNum--;
        }
        require(nodeNum > 4, "less than 5");
    }

    function queryVotes(
        uint256 _proposalId
    )
        external
        view
        returns(
            address[] memory,
            bool,
            address,
            address,
            bytes memory,
            uint256,
            string memory)
    {
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        uint256 len = _proposalMsg.proposers.length;
        address[] memory proposers = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            proposers[i] = _proposalMsg.proposers[i];
        }
        return (proposers, _proposalMsg.proposalSta, _proposalMsg.transparentProxy, _proposalMsg.addr, _proposalMsg.data,
               _proposalMsg.expire, _proposalMsg.label);
    }

    function queryNodes()  external view returns(address[] memory){
        address[] memory nodes = new address[](nodeNum);
        for (uint256 i = 1; i <= nodeNum; i++) {
            nodes[i-1] = nodeIndexAddr[i];
        }
        return nodes;
    }

}
