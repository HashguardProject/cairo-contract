use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use project::backupFactory::IBackupFactoryDispatcher;
use project::backupFactory::IBackupFactoryDispatcherTrait;
use project::backupTemplate::IBackupTemplateDispatcher;
use project::backupTemplate::IBackupTemplateDispatcherTrait;

use core::byte_array::ByteArray;

fn deploy_factory(template_hash: ClassHash) -> ContractAddress {
    let contract = declare("BackupFactory").unwrap().contract_class();
    let mut constructor_calldata = array![template_hash.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_template() -> (ContractAddress, ClassHash) {
    let declared = declare("BackupTemplate").unwrap();
    let contract = declared.contract_class();
    let template_hash = declared.class_hash;
    let mut constructor_calldata = array![starknet::get_caller_address().into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (contract_address, template_hash)
}

#[test]
fn test_factory_deployment() {
    let (_, template_hash) = deploy_template();
    let factory_address = deploy_factory(template_hash);
    
    let factory = IBackupFactoryDispatcher { contract_address: factory_address };
    assert(!factory_address.is_zero(), 'Factory deployment failed');
}

#[test]
fn test_backup_contract_deployment() {
    let (_, template_hash) = deploy_template();
    let factory_address = deploy_factory(template_hash);
    
    let factory = IBackupFactoryDispatcher { contract_address: factory_address };
    
    // Deploy backup contract
    let backup_address = factory.deploy_backup_contract();
    assert(!backup_address.is_zero(), 'Backup deployment failed');
    
    // Verify factory records
    let caller = starknet::get_caller_address();
    let stored_address = factory.get_user_backup_contract(caller);
    assert(stored_address == backup_address, 'Wrong stored address');
    
    // Verify factory deployment flag
    assert(factory.is_factory_deployed(backup_address), 'Not marked as factory deployed');
}

#[test]
#[should_panic(expected: ('User already has backup contract', ))]
fn test_cannot_deploy_multiple_backups() {
    let (_, template_hash) = deploy_template();
    let factory_address = deploy_factory(template_hash);
    
    let factory = IBackupFactoryDispatcher { contract_address: factory_address };
    
    // First deployment should succeed
    factory.deploy_backup_contract();
    
    // Second deployment should fail
    factory.deploy_backup_contract();
} 