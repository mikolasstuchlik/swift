// RUN: %target-swift-frontend -typecheck %s -debug-generic-signatures -requirement-machine-inferred-signatures=on 2>&1 | %FileCheck %s

protocol AProtocol {
  associatedtype B: BProtocol where B.A == Self
}

protocol BProtocol {
  associatedtype A: AProtocol
}

protocol CProtocol {
  associatedtype A: AProtocol
}

protocol DProtocol {
  associatedtype A: AProtocol

  // CHECK-LABEL: .DProtocol.foo(c:)@
  // CHECK-NEXT: <Self, C where Self : DProtocol, C : CProtocol, Self.[DProtocol]A == C.[CProtocol]A>
  func foo<C: CProtocol>(c: C) where C.A == A
}

struct Foo<Value> {
  // CHECK-LABEL: .Foo.bar(c:)@
  // CHECK-NEXT: <Value, C where Value == C.[CProtocol]A, C : CProtocol>
  func bar<C: CProtocol>(c: C) where C.A == Value {}
}
