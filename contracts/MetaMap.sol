pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * MetaMap - A mapping of the decentralized, data-sharing community's
 *           MOST requested information hashes.
 *
 *           *** REAL-TIME | CROWD SOURCED | CRYPTOGRAPHICALLY VERIFIABLE ***
 *
 *           Offered as a public service, with full (or planned) support for
 *           the following communities:
 *
 *               BitTorrent - https://www.bittorrent.com
 *               [ Matrix ] - https://matrix.org
 *               Zer0net    - https://0net.io
 *
 * Version 19.3.11
 *
 * https://d14na.org
 * support@d14na.org
 */


/*******************************************************************************
 *
 * ERC Token Standard #20 Interface
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 */
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


/*******************************************************************************
 *
 * Owned contract
 */
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);

        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;

        newOwner = address(0);
    }
}


/*******************************************************************************
 *
 * Zer0netDb Interface
 */
contract Zer0netDbInterface {
    /* Interface getters. */
    function getAddress(bytes32 _key) external view returns (address);
    function getBool(bytes32 _key)    external view returns (bool);
    function getBytes(bytes32 _key)   external view returns (bytes);
    function getInt(bytes32 _key)     external view returns (int);
    function getString(bytes32 _key)  external view returns (string);
    function getUint(bytes32 _key)    external view returns (uint);

    /* Interface setters. */
    function setAddress(bytes32 _key, address _value) external;
    function setBool(bytes32 _key, bool _value) external;
    function setBytes(bytes32 _key, bytes _value) external;
    function setInt(bytes32 _key, int _value) external;
    function setString(bytes32 _key, string _value) external;
    function setUint(bytes32 _key, uint _value) external;

    /* Interface deletes. */
    function deleteAddress(bytes32 _key) external;
    function deleteBool(bytes32 _key) external;
    function deleteBytes(bytes32 _key) external;
    function deleteInt(bytes32 _key) external;
    function deleteString(bytes32 _key) external;
    function deleteUint(bytes32 _key) external;
}


/*******************************************************************************
 *
 * @notice MetaMap
 *
 *         Public repository of metadata, searchable by info hash.
 *
 * @dev A key-value storage of the most active metadata.
 */
contract MetaMap is Owned {
    /* Initialize predecessor contract. */
    address private _predecessor;

    /* Initialize successor contract. */
    address private _successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /* Set namespace. */
    string _NAMESPACE = 'metamap';

    event Mapping(
        bytes32 indexed dataId,
        bytes metadata
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Set predecessor address. */
        _predecessor = 0x0;

        /* Verify predecessor address. */
        if (_predecessor != 0x0) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = MetaMap(_predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }

        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // _zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
        _zer0netDb = Zer0netDbInterface(0x4C2f68bCdEEB88764b1031eC330aD4DF8d6F64D6); // ROPSTEN
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(_zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.metamap'))) == true);

        _;      // function code is inserted here
    }

    /**
     * THIS CONTRACT DOES NOT ACCEPT DIRECT ETHER
     */
    function () public payable {
        /* Cancel this transaction. */
        revert('Oops! Direct payments are NOT permitted here.');
    }


    /***************************************************************************
     *
     * ACTIONS
     *
     */

    /**
     * Calculate Origin's Data Id
     *
     * Calculates the keccak256 hash of the provided `_originDataId` and
     * its `_resourceId`.
     *
     * Resource Ids
     * -------------------------------------------------
     *     1. torrent (torrent metadata)
     *     2. identity (matrix identity metadata)
     *     3. content (zeronet metadata)
     */
    function calcDataId(
        bytes32 _originDataId,
        string _resourceId
    ) external view returns (
        bytes32 dataId
    ) {
        /* Calculate the data id. */
        dataId = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _resourceId, '.', _originDataId));
    }


    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get Content(.json)
     *
     * Used by Zeronet clients.
     */
    function getContent(
        bytes32 _publicKey
    ) external view returns (
        address location,
        uint blockNum
    ) {
        /* Calculate data id. */
        bytes32 dataId = keccak256(abi.encodePacked(
            _NAMESPACE, '.content.', _publicKey));

        /* Return metadata. */
        return _getMetadata(dataId);
    }

    /**
     * Get Identity
     *
     * Used by [matrix] clients.
     */
    function getIdentity(
        bytes32 _userId
    ) external view returns (
        address location,
        uint blockNum
    ) {
        /* Calculate data id. */
        bytes32 dataId = keccak256(abi.encodePacked(
            _NAMESPACE, '.identity.', _userId));

        /* Return metadata. */
        return _getMetadata(dataId);
    }

    /**
     * Get Info Hash
     *
     * Used by torrent clients.
     */
    function getInfoHash(
        bytes32 _infoHash
    ) external view returns (
        address location,
        uint blockNum
    ) {
        /* Calculate data id. */
        bytes32 dataId = keccak256(abi.encodePacked(
            _NAMESPACE, '.torrent.', _infoHash));

        /* Return metadata. */
        return _getMetadata(dataId);
    }

    /**
     * Get Metadata
     */
    function getMetadata(
        bytes32 _dataId
    ) external view returns (
        address location,
        uint blockNum
    ) {
        /* Return metadata. */
        return _getMetadata(_dataId);
    }

    /**
     * Get Metadata
     *
     * Retrieves the location and block number of the metadata
     * stored for the specified `_dataId`.
     *
     * NOTE: DApps can then read the `Mapping` event from the Ethereum
     *       Event Log, at the specified point, to recover the stored metadata.
     */
    function _getMetadata(
        bytes32 _dataId
    ) private view returns (
        address location,
        uint blockNum
    ) {
        /* Retrieve location. */
        location = _zer0netDb.getAddress(_dataId);

        /* Retrieve block number. */
        blockNum = _zer0netDb.getUint(_dataId);
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() public view returns (uint) {
        return _revision;
    }

    /**
     * Get Predecessor (Address)
     */
    function getPredecessor() public view returns (address) {
        return _predecessor;
    }

    /**
     * Get Successor (Address)
     */
    function getSuccessor() public view returns (address) {
        return _successor;
    }


    /***************************************************************************
     *
     * SETTERS
     *
     */

    /**
     * Set Metadata
     *
     * Stores the location and block number of the metadata being added
     * to the Ethereum Event Log.
     *
     * Cost to Broadcast an Event
     * ---------------------------------------
     *         8 gas per byte of `_data`
     *     + 375 gas per LOG operation
     *     + 375 gas per topic
     *
     * Average Data Sizes
     * -------------------------------------------------
     *     1. Bencoded metadata - ## bytes - ## gas
     *     2. content.json      - ## bytes - ## gas
     *     3. Peer block (sm)   - ## bytes - ## gas
     *     4. Peer block (md)   - ## bytes - ## gas
     *     5. Peer block (lg)   - ## bytes - ## gas
     *
     * Resource Ids
     * -------------------------------------------------
     *     1. torrent (torrent metadata)
     *     2. identity (matrix identity metadata)
     *     3. content (zeronet metadata)
     */
    function setMetadata(
        bytes32 _originDataId,
        string _resourceId,
        bytes _data
    ) onlyAuthBy0Admin external returns (bool success) {
        /* Calculate data id. */
        bytes32 dataId = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _resourceId, '.', _originDataId));

        /* Set location. */
        _zer0netDb.setAddress(dataId, address(this));

        /* Set block number. */
        _zer0netDb.setUint(dataId, block.number);

        /* Broadcast event. */
        emit Mapping(dataId, _data);

        /* Return success. */
        return true;
    }

    /**
     * Set Successor
     *
     * This is the contract address that replaced this current instnace.
     */
    function setSuccessor(
        address _newSuccessor
    ) onlyAuthBy0Admin external returns (bool success) {
        /* Set successor contract. */
        _successor = _newSuccessor;

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * INTERFACES
     *
     */

    /**
     * Supports Interface (EIP-165)
     *
     * (see: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md)
     *
     * NOTE: Must support the following conditions:
     *       1. (true) when interfaceID is 0x01ffc9a7 (EIP165 interface)
     *       2. (false) when interfaceID is 0xffffffff
     *       3. (true) for any other interfaceID this contract implements
     *       4. (false) for any other interfaceID
     */
    function supportsInterface(
        bytes4 _interfaceID
    ) external pure returns (bool) {
        /* Initialize constants. */
        bytes4 InvalidId = 0xffffffff;
        bytes4 ERC165Id = 0x01ffc9a7;

        /* Validate condition #2. */
        if (_interfaceID == InvalidId) {
            return false;
        }

        /* Validate condition #1. */
        if (_interfaceID == ERC165Id) {
            return true;
        }

        // TODO Add additional interfaces here.

        /* Return false (for condition #4). */
        return false;
    }


    /***************************************************************************
     *
     * UTILITIES
     *
     */

    /**
     * Transfer Any ERC20 Token
     *
     * @notice Owner can transfer out any accidentally sent ERC20 tokens.
     *
     * @dev Provides an ERC20 interface, which allows for the recover
     *      of any accidentally sent ERC20 tokens.
     */
    function transferAnyERC20Token(
        address _tokenAddress,
        uint _tokens
    ) public onlyOwner returns (bool success) {
        return ERC20Interface(_tokenAddress).transfer(owner, _tokens);
    }
}
