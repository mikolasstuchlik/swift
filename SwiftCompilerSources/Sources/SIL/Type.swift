//===--- Type.swift - Value type ------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basic
import SILBridging

public struct Type : CustomStringConvertible, NoReflectionChildren {
  public let bridged: BridgedType
  
  public var isAddress: Bool { SILType_isAddress(bridged) != 0 }
  public var isObject: Bool { !isAddress }

  public func isTrivial(in function: Function) -> Bool {
    return SILType_isTrivial(bridged, function.bridged) != 0
  }

  /// Returns true if the type is a trivial type and is and does not contain a Builtin.RawPointer.
  public func isTrivialNonPointer(in function: Function) -> Bool {
    return SILType_isNonTrivialOrContainsRawPointer(bridged, function.bridged) == 0
  }

  public func isReferenceCounted(in function: Function) -> Bool {
    return SILType_isReferenceCounted(bridged, function.bridged) != 0
  }

  public var hasArchetype: Bool { SILType_hasArchetype(bridged) }

  public var isNominal: Bool { SILType_isNominal(bridged) != 0 }
  public var isClass: Bool { SILType_isClass(bridged) != 0 }
  public var isStruct: Bool { SILType_isStruct(bridged) != 0 }
  public var isTuple: Bool { SILType_isTuple(bridged) != 0 }
  public var isEnum: Bool { SILType_isEnum(bridged) != 0 }
  public var isFunction: Bool { SILType_isFunction(bridged) }
  public var isMetatype: Bool { SILType_isMetatype(bridged) }

  /// Can only be used if the type is in fact a nominal type (`isNominal` is true).
  public var nominal: Decl { Decl(bridged: SILType_getNominal(bridged)) }

  public var isOrContainsObjectiveCClass: Bool { SILType_isOrContainsObjectiveCClass(bridged) }

  public var tupleElements: TupleElementArray { TupleElementArray(type: self) }

  public func getNominalFields(in function: Function) -> NominalFieldsArray {
    NominalFieldsArray(type: self, function: function)
  }

  public var instanceTypeOfMetatype: Type { SILType_instanceTypeOfMetatype(bridged).type }

  public var isCalleeConsumedFunction: Bool { SILType_isCalleeConsumedFunction(bridged) }
  
  public func getIndexOfEnumCase(withName name: String) -> Int? {
    let idx = name._withStringRef {
      SILType_getCaseIdxOfEnumType(bridged, $0)
    }
    return idx >= 0 ? idx : nil
  }

  public var description: String {
    String(_cxxString: SILType_debugDescription(bridged))
  }
}

extension Type: Equatable {
  public static func ==(lhs: Type, rhs: Type) -> Bool { 
    lhs.bridged.typePtr == rhs.bridged.typePtr
  }
}

public struct NominalFieldsArray : RandomAccessCollection, FormattedLikeArray {
  fileprivate let type: Type
  fileprivate let function: Function

  public var startIndex: Int { return 0 }
  public var endIndex: Int { SILType_getNumNominalFields(type.bridged) }

  public subscript(_ index: Int) -> Type {
    SILType_getNominalFieldType(type.bridged, index, function.bridged).type
  }

  public func getIndexOfField(withName name: String) -> Int? {
    let idx = name._withStringRef {
      SILType_getFieldIdxOfNominalType(type.bridged, $0)
    }
    return idx >= 0 ? idx : nil
  }

  public func getNameOfField(withIndex idx: Int) -> StringRef {
    StringRef(bridged: SILType_getNominalFieldName(type.bridged, idx))
  }
}

public struct TupleElementArray : RandomAccessCollection, FormattedLikeArray {
  fileprivate let type: Type

  public var startIndex: Int { return 0 }
  public var endIndex: Int { SILType_getNumTupleElements(type.bridged) }

  public subscript(_ index: Int) -> Type {
    SILType_getTupleElementType(type.bridged, index).type
  }
}

extension BridgedType {
  var type: Type { Type(bridged: self) }
}

// TODO: use an AST type for this once we have it
public struct Decl : Equatable {
  let bridged: BridgedDecl

  public static func ==(lhs: Decl, rhs: Decl) -> Bool {
    lhs.bridged == rhs.bridged
  }
}
