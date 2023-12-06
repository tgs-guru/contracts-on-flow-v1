import "MetadataViews"
import "TGSLogging"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSApplication"
import "PropertyService"
import "PropertyProfile"
import "TGSDataCenter"

transaction(
    name: String,
    platform: String,
    platformUid: String,
    propertyKey: String,
    propertyValue: AnyStruct,
    propertyCategory: String?
) {
    let applicationRef: &TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}
    let serviceType: Type

    prepare(acct: AuthAccount) {
        let ctrlCap = acct
            .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
            (from: TGSPlatform.getStandardControllerPath(acct.address))
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")
        let ctrlRef = ctrlCap.borrow()
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")

        let appAddress = ctrlRef.getApplicationAddress(name)
            ?? panic("Application does not exist")
        self.applicationRef = ctrlRef.borrowApplicationPrivate(appAddress)
            ?? panic("Failed to borrow a reference to the application")
        self.serviceType = PropertyService.getServiceIdentityType()

        log("Set Property[".concat(propertyKey).concat("] for User[".concat(platform).concat(":").concat(platformUid).concat("]")))
        log("User Address: ".concat(TGSDataCenter.getAddressByThirdpartyUid(platform, platformUid)?.toString() ?? "Not binded."))
    }

    pre {
        self.applicationRef.borrowProfile(self.serviceType, platform, platformUid) != nil: "Profile should be created before setting property"
    }

    execute {
        let servRef = self.applicationRef.borrowService(self.serviceType)
            ?? panic("Failed to borrow a reference to the service")
        let propertyServRef = servRef.borrowSelf()
            as! &PropertyService.Service{PropertyService.PropertyServicePublic, PropertyService.PropertyServicePrivate}

        let category = propertyCategory ?? "default"
        let profile = self.applicationRef.borrowProfile(self.serviceType, platform, platformUid)
            ?? panic("Failed to borrow a reference to the profile")
        propertyServRef.setProfileProperty(
            registry: category,
            profile: profile.borrowSelf() as! &PropertyProfile.Profile{PropertyProfile.PropertyProfilePublic, PropertyProfile.PropertyProfilePrivate},
            key: propertyKey,
            value: propertyValue
        )
        log("Property Set!")
    }
}
