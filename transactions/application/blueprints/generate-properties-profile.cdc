import "MetadataViews"
import "TGSLogging"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSApplication"
import "PropertyService"
import "PropertyProfile"

transaction(
    name: String,
    platform: String,
    platformUid: String
) {
    let applicationRef: &TGSApplication.Entity{TGSApplication.ApplicationPublic, TGSInterfaces.AccountManagerAccessor, TGSApplication.ApplicationManager, TGSInterfaces.DisplayProperties, MetadataViews.Resolver}
    let serviceType: Type

    prepare(acct: AuthAccount) {
        log("[".concat(name).concat("]Generating Profile: ").concat(platform).concat("-").concat(platformUid))

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
    }

    pre {
        self.applicationRef.borrowProfile(self.serviceType, platform, platformUid) == nil: "Profile already exists"
    }

    execute {
        self.applicationRef.generateAndSaveProfile(self.serviceType, platform, platformUid, {})

        log("PropertyProfile is generated for User[".concat(platform).concat(":").concat(platformUid).concat("]"))
    }
}
