import "MetadataViews"
import "TGSLogging"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSApplication"
import "PropertyService"
import "PropertyProfile"

pub fun main(
    name: String,
    platform: String,
    platformUid: String,
    keys: [String],
    category: String?
): [AnyStruct] {
    let tgsAddr = TGSPlatform.borrowPlatformPublic().owner!.address
    let acct = getAuthAccount(tgsAddr)

    if let ctrlCap = acct
        .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
        (from: TGSPlatform.getStandardControllerPath(acct.address))
    {
        let ctrlRef = ctrlCap.borrow() ?? panic("Could not borrow controller reference")
        if let addr = ctrlRef.getApplicationAddress(name) {
            let app = ctrlRef.borrowApplicationPrivate(addr)
                ?? panic("Could not borrow application reference")
            let serviceType = PropertyService.getServiceIdentityType()

            let servRef = app.borrowService(serviceType)
                ?? panic("Failed to borrow a reference to the service")
            let propertyServRef = servRef.borrowSelf()
                as! &PropertyService.Service{PropertyService.PropertyServicePublic, PropertyService.PropertyServicePrivate}
            let profile = app.borrowProfile(serviceType, platform, platformUid)
            ?? panic("Failed to borrow a reference to the profile")

            let values = propertyServRef.safeGetProfileProperties(
                registry: category ?? "default",
                keys: keys,
                profile: profile.borrowSelf() as! &PropertyProfile.Profile{PropertyProfile.PropertyProfilePublic, PropertyProfile.PropertyProfilePrivate}
            )
            return values
        }
    }
    return []
}
