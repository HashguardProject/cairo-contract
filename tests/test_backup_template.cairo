use starknet::ContractAddress;
use core::traits::Into;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::byte_array::ByteArray;

use project::backupTemplate::IBackupTemplateDispatcher;
use project::backupTemplate::IBackupTemplateDispatcherTrait;

fn deploy_template(owner: ContractAddress) -> ContractAddress {
    let contract = declare("BackupTemplate").unwrap().contract_class();
    let mut constructor_calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn test_template_deployment() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    let stored_owner = template.get_owner();
    assert(stored_owner == owner, 'Wrong owner stored');
}

#[test]
fn test_create_backup() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    
    // Create a backup
    let backup_cid = 123;
    template.create_backup(backup_cid);
    
    // Verify backup creation
    let last_backup_time = template.get_last_backup_time();
    let backup_data = template.get_backup(last_backup_time);
    assert(backup_data.backup_cid == backup_cid, 'Wrong backup CID');
    assert(backup_data.timestamp == last_backup_time, 'Wrong timestamp');
}

#[test]
fn test_backup_settings() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    
    // Test cooldown setting
    let new_cooldown = 3600_u64; // 1 hour
    template.set_backup_cooldown(new_cooldown);
    
    // Test max backups setting
    let new_max = 10_u64;
    template.set_max_backups(new_max);
}

#[test]
#[should_panic(expected: ('Backup cooldown not elapsed', ))]
fn test_backup_cooldown() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    
    // Create first backup
    template.create_backup(123);
    
    // Attempt to create another backup immediately
    template.create_backup(456);
}

#[test]
#[should_panic(expected: ('Only owner can call', ))]
fn test_unauthorized_backup() {
    // Deploy with a different owner
    let owner = starknet::contract_address_const::<0x123>();
    let contract_address = deploy_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    
    // Attempt to create backup as non-owner
    template.create_backup(123);
} 