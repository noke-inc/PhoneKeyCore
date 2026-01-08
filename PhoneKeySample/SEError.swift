//
//  SmartStorageError.swift
//  StorageSmartEntry
//
//  Created by Sean Calkins on 4/1/19.
//  Copyright © 2019 Noke Inc. All rights reserved.
//

import Foundation

public enum SEErrorCode: Int {
    case ErrMemberNotInGroup          =  1
    case ErrRecordingActivity         =  2
    case ErrInput                     =  3
    case ErrLoginAccessRevoked        =  4
    case ErrCompanyAccessRevoked      =  5
    case ErrLoginAttempts            =  6
    case ErrIncorrectPassword         =  7
    case ErrIncorrectCredentials      =  8
    case ErrToken                     =  9
    case ErrInternalServer            =  10
    case ErrPermission                =  11
    case ErrLockNotFound              =  12
    case ErrNoActivity                =  13
    case ErrUsernameExists            =  14
    case ErrNoUsers                   =  15
    case ErrNoPadlocks                =  16
    case ErrNoSchedule                =  17
    case ErrItemDeleted               =  18
    case ErrMemberInGroup             =  19
    case ErrGroupNotFound             =  20
    case ErrActivityRecording         =  21
    case ErrPermissionChecking        =  22
    case ErrNoChanges                 =  23
    case ErrArchiveNotFound           =  24
    case ErrEmailNotFound             =  25
    case ErrIncorrectAppKey           =  26
    case ErrNoQuickClicks             =  27
    case ErrItemNotFound              =  28
    case ErrFobNeedsSetup             =  29
    case ErrJsonFormat                =  30
    case ErrSessionLength             =  31
    case ErrLockNotSetup              =  32
    case ErrNoActiveSchedule          =  33
    case ErrParseSession              =  34
    case ErrMacLength                 =  35
    case ErrNameLength                =  36
    case ErrNotLock                   =  37
    case ErrNotFob                    =  38
    case ErrSessionType               =  39
    case ErrFobNotSetup               =  40
    case ErrFobAlreadySetup           =  42
    case ErrLockAlreadySetup          =  43
    case ErrFobNotFound               =  44
    case ErrNoQCsAvailable            =  45
    case ErrNoExpiredGroups           =  46
    case ErrNoScheduleFound           =  47
    case ErrUserNotFound              =  48
    case ErrCompanyNotFound           =  49
    case ErrTimeOutOfSync             =  50
    case ErrFileUpload                =  51
    case ErrInputImageSize            =  52
    case ErrInputUniqueDomain         =  53
    case ErrRequestMethod             =  54
    case ErrInvalidEndpoint           =  55
    case ErrPaymentFailure            =  56
    case ErrCompanySuspended          =  57
    case ErrInvalidGroupType          =  58
    case ErrDisabledAllSteps          =  59
    case ErrSameUsername              =  60
    case ErrUserMerge                 =  61
    case ErrFeatureNotSupported       =  62
    case ErrInactiveCompany           =  63
    case ErrNoAccessDelinquentPayment =  64
    case ErrAccountNotActive          =  65
    case ErrSelfShare                 =  66
    case ErrAccountNotActiveText      =  67
    case ErrAccountNotActiveEmail     =  68
    case ErrPinExpired                =  69
    case ErrShareNotFound             =  70
    case ErrOverlock                  =  71
    case ErrNoSites                   =  72
    case ErrNoMac                     =  73
    case ErrNoIP                      =  74
    case ErrShortQuery                =  75
    case ErrNoSearchType              =  76
    case ErrPassRequired              =  77
    case ErrUserIdRequired            =  78
    case ErrLockStateRequired         =  79
    case ErrLockIdRequired            =  80
    case ErrInvalidLockState          =  81
    case ErrUnregisteredGateway       =  82
    case ErrSiteNotFound              =  83
    case ErrNoPhoneOrEmail            =  84
    case ErrBillNotPaid               =  85
    case ErrGatewayNoSite             =  86
    case ErrNoAssignedUser            =  87
    case ErrInvalidLockType           =  88
    case ErrInvalidLockName           =  89
    case ErrBadLoginFrozenAccount     =  90
    case ErrInvalidUnitState          =  91
    case ErrAppOutOfDate              =  100
    case ErrGateHours                 =  101
    case ErrNoSitePMS                 =  102
    case ErrMultipleCompanysFound     =  103
    case ErrGatewayNotFound           =  104
    case ErrHistoryNotFound           =  105
    case ErrInvalidFileType           =  106
    case ErrDuplicateAccessCode       =  107
    case ErrPhoneNotUnique            =  108
    case ErrResultsFailedToMatch      =  109
    case ErrNotifyFailed              =  110
    case ErrRoleInUse                 =  111
    case ErrMassUpdateDisallowed      =  112
    case ErrSSOQueryStringMissing     =  113
    case ErrPasswordReuse             =  123
    case ErrInvalidAccount            =  124
    case ErrNotificationsOff          =  125
    case ErrHoldOutsideSiteHours      =  130
    case ErrUnverifiedMethod          =  131
    case ErrSiteNotInInstallerMode    =  132
    case ErrDuplicateLock             =  133
    case ErrInvalidPin                =  136
    case ErrPrelet                    =  137
    case ErrCheckout                  =  138
    case InvalidOfflineKey            =  139
    case InvalidOfflineKeyRekeyed     =  140
    case NokeOneLowBattery            =  141
    case IONJammedUnlocking           =  142
    case ErrInvalidJson               =  150
    case ErrFailedToConnect           =  151
    case ErrFallbackUnlockInProgress  =  152
    
    case EmptySession                 = 998
    case FobNeedsFwUpdate             = 999
    
    //Lock Errors
    case ErrorInvalidKey          = 261 //(200 + 61) INVALIDKEY_ResultType = 0x61
    case ErrorInvalidCmd          = 262 //(200 + 62) INVALIDCMD_ResultType = 0x62
    case ErrorInvalidPermission   = 263 //(200 + 63) INVALIDPERMISSION_ResultType = 0x63
    case ErrorInvalidData         = 265 //(200 + 65) INVALIDDATA_ResultType = 0x65
    case ErrorInvalidResult       = 267 //(200 + FF) INVALID_ResultType = 0xFF
    case DeviceErrorUnknown       = 268
    case OutOfScheduleUnlock      = 269
    case EmptyCommands            = 299
    case FreeExitMessage          = 1003

    
    //Unknown Error
    case Unknown = 1000
    
    case Offline = 1001
    case RequestTimedOut = 1002
    case NoDataReturned = 1004
    
    //Remote Unlock in less than 30 seconds
    case RemoteUnlockInLessThan30Seconds = 1005
    
    //App Generated Errors
    case ErrorNoActiveInstallSites = -10
    
    //No error
    case NoError = 300
    
    
}

public struct SEError: Error {
    public var rawCode: Int = 0
    public var code: SEErrorCode = .NoError
    public var userFacingValue: String = ""
    public var subcode: Int = 0
    public var type: String = ""
    public var jsonSent: [String: Any]?
    public var jsonReceived: [String: Any]?
    public var url: String = ""
    public var endpoint: String = ""
    public var errorID: Int = 0
    public var custom: String = ""
    public var messageString: String = ""
    
    public init(message: String) {
        self.custom = message
    }
    
    public init(userFacingValue: String, code: SEErrorCode) {
        self.userFacingValue = userFacingValue
        self.code = code
    }
    
    public init(code: Int, subcode: Int, type: String, messageString: String = "") {
        self.rawCode = code
        self.code = SEErrorCode(rawValue: code) ?? .Unknown
        self.subcode = subcode
        self.type = type
        self.messageString = messageString
        userFacingValue = string(from: self.code)
    }
    
    public init(rawCode: Int) {
        self.rawCode = rawCode
        self.code = SEErrorCode(rawValue: rawCode) ?? .Unknown
        userFacingValue = string(from: code)
        if isLockError() {
            subcode = 1
            type = "lock"
        }
    }
    
    public func string(from code: SEErrorCode) -> String {
        var errorMessage = ""
        if (code != .NoError) {
            switch code {
                case .ErrPermission: errorMessage = "permission_error".localized()
                case .ErrLoginAttempts, .ErrBadLoginFrozenAccount: errorMessage = "This account has been locked due to excessive failed login attempts. Please wait a few minutes and try again.".localized()
                case .ErrAppOutOfDate: errorMessage = "Your app is out of date, please update and try again.".localized()
                case .ErrorInvalidCmd, .ErrorInvalidKey, .ErrorInvalidData, .ErrorInvalidResult, .DeviceErrorUnknown: errorMessage = "An error has occurred with this unit. Please notify the facility manager.".localized()
                case .EmptyCommands:
                    if(PermissionHelper().isClient()){
                        errorMessage = "access_permission_error".localized()
                    }else{
                        errorMessage = "unit_occupied_error".localized()
                    }
                    
                case .ErrCompanyNotFound, .ErrIncorrectCredentials, .ErrIncorrectPassword, .ErrUserNotFound: errorMessage = "The email, phone number, or password is incorrect. Please check and try again.".localized()
                case .ErrorInvalidPermission, .ErrGateHours: errorMessage = "no_access_error".localized()
                case .ErrOverlock: errorMessage = "overlock_error".localized()
                case .ErrPrelet: errorMessage = "prelet_error".localized()
                case .OutOfScheduleUnlock: errorMessage = "facility_closed_message".localized()
                case .ErrorNoActiveInstallSites: errorMessage = "no_active_install_facilities".localized()
                case .Offline: errorMessage = "no_internet_error".localized()
                case .RequestTimedOut: errorMessage = "request_timed_out".localized()
                case .ErrPasswordReuse: errorMessage = "new_password_cannot_match".localized()
                case .ErrNotificationsOff: errorMessage = "facility_notifications_disabled".localized()
                case .FreeExitMessage: errorMessage = "free_exit_message".localized()
                case .ErrHoldOutsideSiteHours: errorMessage = "hold_outside_facility_hours".localized()
                case .ErrFobNotFound: errorMessage = "fob_not_found".localized()
                case .ErrDuplicateAccessCode: errorMessage = "access_code_exists".localized();
                case .ErrSiteNotInInstallerMode: errorMessage = "facility_not_in_installer_mode".localized()
                case .ErrDuplicateLock: errorMessage = "duplicate_locks_not_uploaded".localized()
                case .ErrCheckout: errorMessage = "checkout_error".localized()
                case .ErrInvalidPin: errorMessage = "invalid_pin".localized()
                case .NokeOneLowBattery: errorMessage = "noke_one_low_battery_error".localized()
                case .RemoteUnlockInLessThan30Seconds : errorMessage = "remote_unlock_in_progress".localized()
                case .IONJammedUnlocking: errorMessage = "jammed_unlocking".localized()
                case .ErrInvalidAccount: errorMessage = "invalid_account_error".localized()
                default:
                    // Add non-fatal error for crashlytics
                    // Log error code
                    errorMessage = "default_error".localized()
            }
        }
        return errorMessage
    }
    
    public func getMessage() -> String {
        //return "\(userFacingValue) S-\(rawCode)"
        return "\(userFacingValue)"
    }
    
    public func getTitle() -> String? {
        return userFacingValue == "default_error".localized() ? nil : "error".localized()
    }
    
    public func isLockError() -> Bool {
        switch code {
        case .ErrorInvalidKey, .ErrorInvalidCmd, .ErrorInvalidPermission, .ErrorInvalidData, .ErrorInvalidResult, .DeviceErrorUnknown, .OutOfScheduleUnlock, .EmptyCommands: return true
        default:
            return false
        }
    }
    
    public func shouldShowDetails() -> Bool {
        return true
    }
    
    public static func failedToConnect(lockName: String) -> SEError {
        return SEError(userFacingValue: "bluetooth_connection_failed".localized(item: lockName), code: SEErrorCode.ErrFailedToConnect)
    }
    
    public static func fallbackUnlockInProgress() -> SEError {
        return SEError(userFacingValue: "fallback_remote_unlock_in_progress".localized(), code: SEErrorCode.ErrFailedToConnect)
    }
    
    public static func outOfSchedule() -> SEError {
        return SEError.init(rawCode: SEErrorCode.ErrGateHours.rawValue)
    }
    
    public static func overlock() -> SEError {
        return SEError.init(rawCode: SEErrorCode.ErrOverlock.rawValue)
    }
}
