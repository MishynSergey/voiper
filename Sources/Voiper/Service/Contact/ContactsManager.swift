import CallKit
import Contacts
import ContactsUI
import Foundation
import PromiseKit
import KeychainAccess

public class ContactsManager {
    
    public static let contactsUpdateNotification = Notification.Name("contactsUpdateNotification")
    var store = CNContactStore()
    public static let shared = ContactsManager()
    public var contacts: [Contact] = []
    public var cnContacts: [CNContact] = []

    private init() {
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            loadContacts(filter: .none)
        }
    }
    
    public func requestAccess(completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            Settings.hasAccessContact = true
            completionHandler(true)
        case .denied:
            Settings.hasAccessContact = false
            completionHandler(false)
        case .restricted, .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                if granted {
                    Settings.hasAccessContact = true
                    completionHandler(true)
                } else {
                    Settings.hasAccessContact = false
                }
            }
        @unknown default:
            break
        }
    }

    
    public func createContact(with phone: String?) -> CNContact {
        let contact = CNMutableContact()
        if let phone = phone {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        return contact
    }
    

    class func getContacts(filter: ContactsFilter = .none) -> [CNContact] {
            let contactStore = CNContactStore()
            let keysToFetch = [
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactImageDataAvailableKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactViewController.descriptorForRequiredKeys() as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor] as [CNKeyDescriptor]
            
            var allContainers: [CNContainer] = []
            do {
                allContainers = try contactStore.containers(matching: nil)
            } catch {
                print("Error fetching containers")
            }
            var results: [CNContact] = []
            
            for container in allContainers {
                let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                
                do {
                    let containerResults = try contactStore.unifiedContacts(matching: fetchPredicate, keysToFetch: keysToFetch)
                    results.append(contentsOf: containerResults)
                } catch {
                    print("Error fetching containers")
                }
            }
            return results
    }

    public enum ContactsFilter {
        case none
        case mail
        case message
    }


    public func contactBy(id: String) -> Contact? {
        contacts.first(where: { $0.id == id })
    }
    
    public func contacts(filterNumber: String) -> [Contact] {
        return contacts.filter { contact in
            contact.phones.contains { $0.phone.contains(filterNumber) }
        }
    }
    
    
    public func searchContactWithPhoneNumber(phoneNumber: String, completion: @escaping (CNContact?) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            let contactStore = CNContactStore()
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactImageDataAvailableKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactViewController.descriptorForRequiredKeys() as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor
            ]

            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            var matchingContact: CNContact?

            do {
                try contactStore.enumerateContacts(with: fetchRequest) { contact, stop in
                    for phoneNumberValue in contact.phoneNumbers {
                        if let number = phoneNumberValue.value.stringValue.phoneNumberClean.components(separatedBy: CharacterSet.decimalDigits.inverted).joined() as String? {
                            if number == phoneNumber {
                                matchingContact = contact
                                stop.pointee = true
                                break
                            }
                        }
                    }
                }
            } catch {
                print("Error enumerating contacts: \(error)")
            }
            DispatchQueue.main.async {
                completion(matchingContact)
            }
        }
    }

    
    
    public func contactBy(phone: String, completion: (Contact?) -> Void) {
        let contactStore = CNContactStore()
        let keysToFetch = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactViewController.descriptorForRequiredKeys() as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor] as [CNKeyDescriptor]

        var contacts = [CNContact]()
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        do {
            try contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact, _) in
                for phoneNumberValue in contact.phoneNumbers {
                    if let number = phoneNumberValue.value.stringValue.lowercased().components(separatedBy: CharacterSet.decimalDigits.inverted).joined() as String? {
                        if number.range(of: phone.lowercased(), options: .caseInsensitive) != nil {
                            contacts.append(contact)
                            break
                        }
                    }
                }
                if let contact = contacts.first {
                    return completion(Contact(cnContact: contact))
                } else {
                    completion(nil)
                }
            })
        } catch {
            completion(nil)
        }
    }
    
    public func cnContact(by id: String) -> CNContact? {
        return cnContacts.first(where:  {$0.identifier == id})
    }

    public func loadContacts(filter: ContactsFilter, completion: (() -> Void)? = nil) {
        requestAccess { accessGranted in
            var allContacts = [Contact]()
            let cnContacts = ContactsManager.getContacts(filter: filter)
            
            for contact in cnContacts {
                if let contact = Contact(cnContact: contact) {
                    allContacts.append(contact)
                }
            }
            
            self.cnContacts = cnContacts
            self.contacts = allContacts.filter({!$0.phones.isEmpty && !$0.firstName.isEmpty && $0.firstName != ""})
            completion?()
            NotificationCenter.default.post(Notification(name: ContactsManager.contactsUpdateNotification))
        }
    }
}

enum ContactStoreError: Error {
    case noAccess
}
