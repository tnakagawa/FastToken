//

const OPEN_REQUEST_TYPES = {
    OpenRequest: [
        { type: "address", name: "channel" },
        { type: "uint256", name: "index" },
        { type: "uint256", name: "total" },
        { type: "uint256", name: "amount1" },
        { type: "uint256", name: "amount2" },
        { type: "uint256", name: "nonce" },
        { type: "uint256", name: "deadline" },
    ],
};

const CLOSE_REQUEST_TYPES = {
    CloseRequest: [
        { type: "address", name: "channel" },
        { type: "uint256", name: "index" },
        { type: "uint256", name: "amount1" },
        { type: "uint256", name: "amount2" },
        { type: "uint256", name: "nonce" },
        { type: "uint256", name: "deadline" },
    ],
};

const HOLD_REQUEST_TYPES = {
    HoldRequest: [
        { type: "address", name: "channel" },
        { type: "uint256", name: "index" },
        { type: "uint256", name: "amount1" },
        { type: "uint256", name: "amount2" },
        { type: "uint256", name: "count" },
        { type: "uint256", name: "lockterm" },
        { type: "bytes32", name: "payHash" },
    ],
};


const INCREASE_REQUEST_TYPES = {
    IncreaseRequest: [
        { type: "address", name: "channel" },
        { type: "uint256", name: "index" },
        { type: "uint256", name: "amount1" },
        { type: "uint256", name: "amount2" },
        { type: "uint256", name: "nonce" },
        { type: "uint256", name: "deadline" },
    ],
};

const DECREASE_REQUEST_TYPES = {
    DecreaseRequest: [
        { type: "address", name: "channel" },
        { type: "uint256", name: "index" },
        { type: "uint256", name: "amount1" },
        { type: "uint256", name: "amount2" },
        { type: "uint256", name: "nonce" },
        { type: "uint256", name: "deadline" },
    ],
};


async function getDomain(contract) {
    let eip712domain = await contract.eip712Domain();
    let domain = {
        chainId: eip712domain.chainId,
        name: eip712domain.name,
        verifyingContract: eip712domain.verifyingContract,
        version: eip712domain.version,
    };
    return domain;
}


module.exports = {
    OPEN_REQUEST_TYPES,
    CLOSE_REQUEST_TYPES,
    HOLD_REQUEST_TYPES,
    INCREASE_REQUEST_TYPES,
    DECREASE_REQUEST_TYPES,
    getDomain,
};