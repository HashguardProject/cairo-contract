use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use project::complexe_storage::IComplexStorageSafeDispatcher;
use project::complexe_storage::IComplexStorageSafeDispatcherTrait;
use project::complexe_storage::IComplexStorageDispatcher;
use project::complexe_storage::IComplexStorageDispatcherTrait;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_store_file() {
    let contract_address = deploy_contract("ComplexStorage");

    let dispatcher = IComplexStorageDispatcher { contract_address };

    dispatcher.store_file(254, 365, 'name');

    let numberOfFiles = dispatcher.get_file_number();
    assert(numberOfFiles == 1, 'Invalid number of files');

    let (cid, key, name) = dispatcher.get_file(0);
    assert(cid == 254, 'Invalid cid');
    assert(key == 365, 'Invalid key');
    assert(name == 'name', 'Invalid name');
}

#[test]
fn test_replace_file() {
    let contract_address = deploy_contract("ComplexStorage");

    let dispatcher = IComplexStorageDispatcher { contract_address };

    dispatcher.store_file(254, 365, 'name');

    let numberOfFiles = dispatcher.get_file_number();
    assert(numberOfFiles == 1, 'Invalid number of files');

    dispatcher.replace_file(0, 123, 456, 'new name');

    let (cid, key, name) = dispatcher.get_file(0);
    assert(cid == 123, 'Invalid cid');
    assert(key == 456, 'Invalid key');
    assert(name == 'new name', 'Invalid name');
}
