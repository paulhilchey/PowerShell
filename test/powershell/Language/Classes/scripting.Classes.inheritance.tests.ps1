# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Classes inheritance syntax' -Tags "CI" {

    It 'Base types' {
        class C1 {}
        class C2a : C1 {}
        class C2b:C1 {}

        [C2a]::new().GetType().BaseType.Name | Should -Be "C1"
        [C2b].BaseType.Name | Should -Be "C1"
    }

    It 'inheritance from abstract base class with no abstract methods and protected ctor' {
        class C3 : system.collections.collectionbase {}

        class C4 { C4([int]$a) {} }
        class C5 : C4 { C5() : base(1) {} }
    }

    It 'inheritance from base class with implicit ctor' {
        class C6 {}
        class C7 : C6 { C7() : base() {} }
    }

    It 'inheritance syntax allows newlines in various places' {
        class C {}
        class C2a:C,system.IDisposable{ [void] Dispose() { }}
        class C2b
            :
            C
            ,
            system.IDisposable
            {
                [void] Dispose() {}
                C2b()
                :   # there are extra spaces here
                base
                (
                )
                {
                }
            }

        [C2a].GetInterface("System.IDisposable") | Should -Not -BeNullOrEmpty
        [C2b].GetInterface("System.IDisposable") | Should -Not -BeNullOrEmpty
    }

    It 'can subclass .NET type' {
        class MyIntList : system.collections.generic.list[int] {}
        [MyIntList]::new().GetType().BaseType.FullName.StartsWith('System.Collections.Generic.List') | Should -BeTrue
    }

    It 'can implement .NET interface' {
        class MyComparable : system.IComparable
        {
            [int] CompareTo([object] $obj)
            {
                return 0;
            }
        }
        [MyComparable].GetInterface("System.IComparable") | Should -Not -BeNullOrEmpty
    }

    It 'can implement .NET interface properties' {
        Add-Type -TypeDefinition 'public interface InterfaceWithProperty { int Integer { get; set; } }'
        $C1 = Invoke-Expression 'class ClassWithInterfaceProperty : InterfaceWithProperty { [int]$Integer } [ClassWithInterfaceProperty]::new()'
        $getter = $C1.GetType().GetMember('get_Integer')
        $getter.ReturnType.FullName | Should -Be System.Int32
        $getter.Attributes -band [System.Reflection.MethodAttributes]::Virtual | Should -Be ([System.Reflection.MethodAttributes]::Virtual)
    }

    It 'can implement inherited .NET interface properties' {
        Add-Type -TypeDefinition 'public interface IParent { int ParentInteger { get; set; } }
                                  public interface IChild : IParent { int ChildInteger { get; set; } }'
        $C1 = Invoke-Expression 'class ClassWithInheritedInterfaces : IChild { [int]$ParentInteger; [int]$ChildInteger } [ClassWithInheritedInterfaces]'
        $getter = $C1.GetMember('get_ParentInteger')
        $getter.ReturnType.FullName | Should -Be System.Int32
        $getter.Attributes -band [System.Reflection.MethodAttributes]::Virtual | Should -Be ([System.Reflection.MethodAttributes]::Virtual)
    }

    It 'can implement .NET interface static properties' {
        Add-Type -TypeDefinition @'
public interface IInterfaceWithStaticAbstractProperty
{
    static abstract int Getter { get; }
    static abstract int Setter { get; set; }
}

public static class InterfaceStaticAbstractPropertyTest
{
    public static int GetGetter<T>() where T : IInterfaceWithStaticAbstractProperty
        => T.Getter;

    public static int GetSetter<T>() where T : IInterfaceWithStaticAbstractProperty
        => T.Setter;

    public static int SetSetter<T>(int value) where T : IInterfaceWithStaticAbstractProperty
        => T.Setter = value;
}
'@

        $C1 = Invoke-Expression @'
class ClassWithStaticAbstractInterface : IInterfaceWithStaticAbstractProperty {
    static [int]$Getter = 1
    static [int]$Setter = 2
}

[ClassWithStaticAbstractInterface]
'@

        $C1::Getter | Should -Be 1
        $C1::Getter | Should -BeOfType ([int])
        $C1::Setter | Should -Be 2
        $C1::Setter | Should -BeOfType ([int])
        $C1::Setter = 3
        $C1::Setter | Should -Be 3

        [InterfaceStaticAbstractPropertyTest]::GetGetter[ClassWithStaticAbstractInterface]() | Should -Be 1
        [InterfaceStaticAbstractPropertyTest]::GetSetter[ClassWithStaticAbstractInterface]() | Should -Be 3
        [InterfaceStaticAbstractPropertyTest]::SetSetter[ClassWithStaticAbstractInterface](4)
        [InterfaceStaticAbstractPropertyTest]::GetSetter[ClassWithStaticAbstractInterface]() | Should -Be 4
    }

    It 'allows use of defined later type as a property type' {
        class A { static [B]$b }
        class B : A {}
        [A]::b = [B]::new()
        { [A]::b = "bla" } | Should -Throw -ErrorId 'ExceptionWhenSetting'
    }

    Context "Inheritance from abstract .NET classes" {
        BeforeAll {
            class TestHost : System.Management.Automation.Host.PSHost
            {
                [String]$myName = "MyHost"
                [Version]$myVersion = [Version]"1.0.0.0"
                [Guid]$myInstanceId = [guid]::NewGuid()
                [System.Globalization.CultureInfo]$myCurrentCulture = "en-us"
                [System.Globalization.CultureInfo]$myCurrentUICulture = "en-us"
                [System.Management.Automation.Host.PSHostUserInterface]$myUI = $null
                [bool]$IsInteractive
                [void]SetShouldExit([int]$exitCode) { }
                [void]EnterNestedPrompt(){ throw "EnterNestedPrompt-NotSupported" }
                [void]ExitNestedPrompt(){ throw "Unsupported" }
                [void]NotifyBeginApplication() { }
                [void]NotifyEndApplication() { }
                [string]get_Name() { return $this.myName; Write-Host "MyName" }
                [version]get_Version() { return $this.myVersion }
                [System.Globalization.CultureInfo]get_CurrentCulture() { return $this.myCurrentCulture }
                [System.Globalization.CultureInfo]get_CurrentUICulture() { return $this.myCurrentUICulture }
                [System.Management.Automation.Host.PSHostUserInterface]get_UI() { return $this.myUI }
                [guid]get_InstanceId() { return $this.myInstanceId }
                TestHost() {
                }
                TestHost([bool]$isInteractive) {
                    $this.IsInteractive = $isInteractive
                }
            }
        }

        It 'can subclass .NET abstract class' {
            $th = [TestHost]::new()
            $th.myName    | Should -BeExactly "MyHost"
            $th.myVersion | Should -Be ([Version]"1.0.0.0")
        }

        It 'overrides abstract base class properties' {
            $th = [TestHost]::new()
            $th.Name | Should -BeExactly "MyHost"
        }

        It 'overrides abstract base class methods' {
            $th = [TestHost]::new()
            { $th.EnterNestedPrompt() } | Should -Throw "EnterNestedPrompt-NotSupported"
        }
    }
}

Describe 'Classes inheritance syntax errors' -Tags "CI" {
    ShouldBeParseError "class A : NonExistingClass {}" TypeNotFound 10
    ShouldBeParseError "class A : {}" TypeNameExpected 9
    ShouldBeParseError "class A {}; class B : A, {}" TypeNameExpected 24
    ShouldBeParseError "class A{} ; class B : A[] {}" SubtypeArray 22 -SkipAndCheckRuntimeError
    ShouldBeParseError "class A : System.Collections.Generic.List``1 {}" SubtypeUnclosedGeneric 10 -SkipAndCheckRuntimeError

    ShouldBeParseError "class A {}; class B : A, NonExistingInterface {}" TypeNotFound 25
    ShouldBeParseError "class A {} ; class B {}; class C : A, B {}" InterfaceNameExpected 38 -SkipAndCheckRuntimeError
    ShouldBeParseError "class A{} ; class B : A, System.IDisposable[] {}" SubtypeArray 25 -SkipAndCheckRuntimeError
    ShouldBeParseError "class A {}; class B : A, NonExistingInterface {}" TypeNotFound 25

    # base should be accepted only on instance ctors
    ShouldBeParseError 'class A { A($a){} } ; class B : A { foo() : base(1) {} }' MissingFunctionBody 41
    ShouldBeParseError 'class A { static A() {} }; class B { static B() : base() {} }' MissingFunctionBody 47

    # Incomplete input
    ShouldBeParseError 'class A { A($a){} } ; class B : A { B() : bas {} }' MissingBaseCtorCall 41
    ShouldBeParseError 'class A { A($a){} } ; class B : A { B() : base( {} }' @('MissingEndParenthesisInMethodCall', 'MissingFunctionBody') @(50, 39)
    ShouldBeParseError 'class A { A($a){} } ; class B : A { B() : base {} }' @('MissingMethodParameterList', 'UnexpectedToken') @(46, 50)

    # Sealed base
    ShouldBeParseError "class baz : string {}" SealedBaseClass 12 -SkipAndCheckRuntimeError
    # Non-existing Interface
    ShouldBeParseError "class bar {}; class baz : bar, Non.Existing.Interface {}" TypeNotFound 31 -SkipAndCheckRuntimeError

    # .NET abstract method not implemented
    ShouldBeParseError "class MyType : Type {}" TypeCreationError 0 -SkipAndCheckRuntimeError

    # inheritance doesn't allow non linear order
    ShouldBeParseError "class A : B {}; class B {}" TypeNotFound 10 -SkipAndCheckRuntimeError

    # inheritance doesn't allow circular order
    ShouldBeParseError "class A : B {}; class B : A {}" TypeNotFound 10 -SkipAndCheckRuntimeError
    ShouldBeParseError "class A : C {}; class B : A {}; class C : B {}" TypeNotFound 10 -SkipAndCheckRuntimeError
}

Describe 'Classes methods with inheritance' -Tags "CI" {

    Context 'Method calls' {

        It 'can call instance method on base class' {
            class bar
            {
                [int]foo() {return 100500}
            }
            class baz : bar {}
            [baz]::new().foo() | Should -Be 100500
        }

        It 'can call static method on base class' {
            class bar
            {
                static [int]foo() {return 100500}
            }
            class baz : bar {}
            [baz]::foo() | Should -Be 100500
        }

        It 'can access static and instance base class property' {
            class A
            {
                static [int]$si
                [int]$i
            }
            class B : A
            {
                [void]foo()
                {
                    $this::si = 1001
                    $this.i = 1003
                }
            }
            $b = [B]::new()
            $b.foo()
            [A]::si | Should -Be 1001
            ($b.i) | Should -Be 1003
        }

        It 'works with .NET types' {
            class MyIntList : system.collections.generic.list[int] {}
            $intList = [MyIntList]::new()
            $intList.Add(100501)
            $intList.Add(100502)
            $intList.Count | Should -Be 2
            $intList[0] | Should -Be 100501
            $intList[1] | Should -Be 100502
        }

        It 'overrides instance method' {
            class bar
            {
                [int]foo() {return 100500}
            }
            class baz : bar
            {
                [int]foo() {return 200600}
            }
            [baz]::new().foo() | Should -Be 200600
        }

        It 'allows base .NET class method call and doesn''t fall into recursion' {
            Add-Type -TypeDefinition @'
                public class BaseMembersTestClass
                {
                    public virtual int PublicMethod()
                    {
                        return 1001;
                    }

                    protected virtual int FamilyMethod()
                    {
                        return 2002;
                    }

                    protected internal virtual int FamilyOrAssemblyMethod()
                    {
                        return 3003;
                    }
                }
'@
            $derived = Invoke-Expression @'
                class BaseCallTestClass : BaseMembersTestClass
                {
                    hidden [int] $publicMethodCallCounter
                    [int] PublicMethod()
                    {
                        if ($this.publicMethodCallCounter++ -gt 0)
                        {
                            throw "Recursion happens"
                        }
                        return 3 * ([BaseMembersTestClass]$this).PublicMethod()
                    }

                    hidden [int] $familyMethodCallCounter
                    [int] FamilyMethod()
                    {
                        if ($this.familyMethodCallCounter++ -gt 0)
                        {
                            throw "Recursion happens"
                        }
                        return 3 * ([BaseMembersTestClass]$this).FamilyMethod()
                    }

                    hidden [int] $familyOrAssemblyMethodCallCounter
                    [int] FamilyOrAssemblyMethod()
                    {
                        if ($this.familyOrAssemblyMethodCallCounter++ -gt 0)
                        {
                            throw "Recursion happens"
                        }
                        return 3 * ([BaseMembersTestClass]$this).FamilyOrAssemblyMethod()
                    }
                }

                [BaseCallTestClass]::new()
'@

            $derived.PublicMethod() | Should -Be 3003
            $derived.FamilyMethod() | Should -Be 6006
            $derived.FamilyOrAssemblyMethod() | Should -Be 9009
        }

        It 'allows base PowerShell class method call and doesn''t fall into recursion' {
            class bar
            {
                [int]foo() {return 1001}
            }
            class baz : bar
            {
                [int] $fooCallCounter
                [int]foo()
                {
                    if ($this.fooCallCounter++ -gt 0)
                    {
                        throw "Recursion happens"
                    }
                    return 3 * ([bar]$this).foo()
                }
            }

            $res = [baz]::new().foo()
            $res | Should -Be 3003
        }

        It 'case insensitive for base class method calls' {
            class bar
            {
                [int]foo() {return 1001}
            }
            class baz : bar
            {
                [int] $fooCallCounter
                [int]fOo()
                {
                    if ($this.fooCallCounter++ -gt 0)
                    {
                        throw "Recursion happens"
                    }
                    return ([bAr]$this).fOo() + ([bAr]$this).FOO()
                }
            }

            $res = [baz]::new().foo()
            $res | Should -Be 2002
        }

        It 'allows any call from the inheritance hierarchy' {
            class A
            {
                [string]GetName() {return "A"}
            }
            class B : A
            {
                [string]GetName() {return "B"}
            }
            class C : B
            {
                [string]GetName() {return "C"}
            }
            class D : C
            {
                [string]GetName() {return "D"}
            }
            $d = [D]::new()

            ([A]$d).GetName() | Should -Be "A"
            ([B]$d).GetName() | Should -Be "B"
            ([C]$d).GetName() | Should -Be "C"
            ([D]$d).GetName() | Should -Be "D"
            $d.GetName() | Should -Be "D"
        }

        It 'can call base method with params' {
            class A
            {
                [string]ToStr([int]$a) {return "A" + $a}
            }
            class B : A
            {
                [string]ToStr([int]$a) {return "B" + $a}
            }
            $b = [B]::new()
            ([A]$b).ToStr(101) | Should -Be "A101"
            $b.ToStr(100) | Should -Be "B100"
        }

        It 'can call base method with many params' {
            class A
            {
                [string]ToStr([int]$a1, [int]$a2, [int]$a3, [int]$a4, [int]$a5, [int]$a6, [int]$a7, [int]$a8, [int]$a9, [int]$a10, [int]$a11, [int]$a12, [int]$a13, [int]$a14)
                {
                    return "A"
                }

                [void]Noop([int]$a1, [int]$a2, [int]$a3, [int]$a4, [int]$a5, [int]$a6, [int]$a7, [int]$a8, [int]$a9, [int]$a10, [int]$a11, [int]$a12, [int]$a13, [int]$a14)
                {
                }
            }
            class B : A
            {
                [string]ToStr([int]$a1, [int]$a2, [int]$a3, [int]$a4, [int]$a5, [int]$a6, [int]$a7, [int]$a8, [int]$a9, [int]$a10, [int]$a11, [int]$a12, [int]$a13, [int]$a14)
                {
                    return "B"
                }

                [void]Noop([int]$a1, [int]$a2, [int]$a3, [int]$a4, [int]$a5, [int]$a6, [int]$a7, [int]$a8, [int]$a9, [int]$a10, [int]$a11, [int]$a12, [int]$a13, [int]$a14)
                {
                }
            }
            $b = [B]::new()

            # we don't really care about methods results, we only checks that calls doesn't throw

            # 14 args is a limit
            $b.ToStr(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14) | Should -Be 'B'
            ([A]$b).ToStr(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14) | Should -Be 'A'

            # 14 args is a limit
            $b.Noop(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
            ([A]$b).Noop(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
        }

        It 'overrides void method call' {
            $script:voidOverrideVar = $null
            class A
            {
                [void]SetStr([int]$a) {$script:voidOverrideVar = "A" + $a}
                [void]SetStr() {$script:voidOverrideVar = "A"}
            }
            class B : A
            {
                [void]SetStr([int]$a) {$script:voidOverrideVar = "B" + $a}
                [void]SetStr() {$script:voidOverrideVar = "B"}
            }
            $b = [B]::new()
            ([A]$b).SetStr(101)
            $script:voidOverrideVar | Should -Be "A101"
            $b.SetStr(100)
            $script:voidOverrideVar | Should -Be "B100"
            ([A]$b).SetStr()
            $script:voidOverrideVar | Should -Be "A"
            $b.SetStr()
            $script:voidOverrideVar | Should -Be "B"
        }

        It 'hides final .NET method' {
            class MyIntList : system.collections.generic.list[int]
            {
                # Add is final, can we hide it?
                [void] Add([int]$arg)
                {
                    ([system.collections.generic.list[int]]$this).Add($arg * 2)
                }
            }

            $intList = [MyIntList]::new()
            $intList.Add(100201)
            $intList.Count | Should -Be 1
            $intList[0] | Should -Be 200402
        }
    }

    Context 'base static method call' {
        class A
        {
            static [string]ToStr([int]$a) {return "A" + $a}
        }
        class B : A
        {
            static [string]ToStr([int]$a) {return "B" + $a}
        }

        $b = [B]::new()

        # MSFT:1911652
        # MSFT:2973835
        It 'doesn''t affect static method call on type' -Skip {
            ([A]$b)::ToStr(101) | Should -Be "A101"
        }

        It 'overrides static method call on instance' {
            $b::ToStr(100) | Should -Be "B100"
        }
    }
}

Describe 'Classes inheritance ctors syntax errors' -Tags "CI" {

    #DotNet.Interface.NotImplemented
    ShouldBeParseError "class MyComparable : system.IComparable {}" TypeCreationError 0 -SkipAndCheckRuntimeError

    #DotNet.Interface.WrongSignature
    ShouldBeParseError 'class MyComparable : system.IComparable { [void] CompareTo([object]$obj) {} }' TypeCreationError 0 -SkipAndCheckRuntimeError

    #DotNet.NoDefaultCtor
    ShouldBeParseError "class MyCollection : System.Collections.ObjectModel.ReadOnlyCollection[int] {}" BaseClassNoDefaultCtor 0 -SkipAndCheckRuntimeError

    #NoDefaultCtor
    ShouldBeParseError 'class A { A([int]$a) {} }; class B : A {}' BaseClassNoDefaultCtor 27 -SkipAndCheckRuntimeError
}

Describe 'Classes inheritance ctors' -Tags "CI" {

    It 'can call base ctor' {
        class A {
            [int]$a
            A([int]$a)
            {
                $this.a = $a
            }
        }

        class B : A
        {
            B([int]$a) : base($a * 2) {}
        }

        $b = [B]::new(101)
        $b.a | Should -Be 202
    }

    # TODO: can we detect it in the parse time?
    It 'cannot call base ctor with the wrong number of parameters' {
        class A {
            [int]$a
            A([int]$a)
            {
                $this.a = $a
            }
        }

        class B : A
        {
            B([int]$a) : base($a * 2, 100) {}
        }

        { [B]::new(101) } | Should -Throw -ErrorId "MethodCountCouldNotFindBest"
    }

    It 'call default base ctor implicitly' {
        class A {
            [int]$a
            A()
            {
                $this.a = 1007
            }
        }

        class B : A
        {
            B() {}
        }

        class C : A
        {
        }

        $b = [B]::new()
        $c = [C]::new()
        $b.a | Should -Be 1007
        $c.a | Should -Be 1007
    }

    It 'doesn''t allow base ctor as an explicit method call' {
        $o = [object]::new()
        # we should not allow direct .ctor call.
        { $o.{.ctor}() } | Should -Throw -ErrorId "MethodNotFound"
    }

    It 'allow use conversion [string -> int] in base ctor call' {
        class A {
            [int]$a
            A([int]$a)
            {
                $this.a = $a
            }
        }

        class B : A
        {
            B() : base("103") {}
        }

        $b = [B]::new()
        $b.a | Should -Be 103
    }

    It 'resolves ctor call based on argument type' {
        class A {
            [int]$i
            [string]$s
            A([int]$a)
            {
                $this.i = $a
            }
            A([string]$a)
            {
                $this.s = $a
            }
        }

        class B : A
        {
            B($a) : base($a) {}
        }

        $b1 = [B]::new("foo")
        $b2 = [B]::new(1001)
        $b1.s | Should -Be "foo"
        $b2.i | Should -Be 1001
    }
}

Describe 'Type creation' -Tags "CI" {
    It 'can call super-class methods sequentially' {
        $sb = [scriptblock]::Create(@'
class Base
{
    [int] foo() { return 100 }
}

class Derived : Base
{
    [int] foo() { return 2 * ([Base]$this).foo() }
}

[Derived]::new().foo()
'@)
        $sb.Invoke() | Should -Be 200
        $sb.Invoke() | Should -Be 200
    }
}

Describe 'Base type has abstract properties' -Tags "CI" {
    It 'can derive from `FileSystemInfo`' {
        ## FileSystemInfo has 3 abstract members that a derived type needs to implement
        ##  - public abstract bool Exists { get; }
        ##  - public abstract string Name { get; }
        ##  - public abstract void Delete ();

        class myFileSystemInfo : System.IO.FileSystemInfo
        {
            [string] $Name
            [bool] $Exists

            myFileSystemInfo([string]$path)
            {
                # ctor
                $this.Name = $path
                $this.Exists = $true
            }

            [void] Delete()
            {
            }
        }

        $myFile = [myFileSystemInfo]::new('Hello')
        $myFile.Name | Should -Be 'Hello'
        $myFile.Exists | Should -BeTrue
    }

    It 'deriving from `FileSystemInfo` will fail when the abstract property `Exists` is not implemented' {
        $script = [scriptblock]::Create('class WillFail : System.IO.FileSystemInfo { [string] $Name }')
        $failure = $null
        try {
            & $script
        } catch {
            $failure = $_
        }

        $failure | Should -Not -BeNullOrEmpty
        $failure.FullyQualifiedErrorId | Should -BeExactly "TypeCreationError"
        $failure.Exception.Message | Should -BeLike "*'get_Exists'*"
    }
}

Describe 'Classes inheritance with protected and protected internal members in base class' -Tags 'CI' {

    BeforeAll {
        Set-StrictMode -Version 3
        $c1DefinitionProtectedInternal = @'
            public class C1ProtectedInternal
            {
                protected internal string InstanceField = "C1_InstanceField";
                protected internal string InstanceProperty { get; set; } = "C1_InstanceProperty";
                protected internal string InstanceMethod() { return "C1_InstanceMethod"; }

                protected internal virtual string VirtualProperty1 { get; set; } = "C1_VirtualProperty1";
                protected internal virtual string VirtualProperty2 { get; set; } = "C1_VirtualProperty2";
                protected internal virtual string VirtualMethod1() { return "C1_VirtualMethod1"; }
                protected internal virtual string VirtualMethod2() { return "C1_VirtualMethod2"; }

                public string CtorUsed {  get; set; }
                public C1ProtectedInternal() { CtorUsed = "default ctor"; }
                protected internal C1ProtectedInternal(string p1) { CtorUsed = "C1_ctor_1args:" + p1; }
            }
'@
        $c2DefinitionProtectedInternal = @'
            class C2ProtectedInternal : C1ProtectedInternal {
                C2ProtectedInternal() : base() { $this.VirtualProperty2 = 'C2_VirtualProperty2' }
                C2ProtectedInternal([string]$p1) : base($p1) { $this.VirtualProperty2 = 'C2_VirtualProperty2' }

                [string]GetInstanceField() { return $this.InstanceField }
                [string]SetInstanceField([string]$value) { $this.InstanceField = $value; return $this.InstanceField }
                [string]GetInstanceProperty() { return $this.InstanceProperty }
                [string]SetInstanceProperty([string]$value) { $this.InstanceProperty = $value; return $this.InstanceProperty }
                [string]CallInstanceMethod() { return $this.InstanceMethod() }

                [string]GetVirtualProperty1() { return $this.VirtualProperty1 }
                [string]SetVirtualProperty1([string]$value) { $this.VirtualProperty1 = $value; return $this.VirtualProperty1 }
                [string]CallVirtualMethod1() { return $this.VirtualMethod1() }

                [string]$VirtualProperty2
                [string]VirtualMethod2() { return 'C2_VirtualMethod2' }
                # Note: Overriding a virtual property in a derived PowerShell class prevents access to the
                #       base property via simple typecast ([base]$this).VirtualProperty2.
                [string]GetVirtualProperty2() { return $this.VirtualProperty2 }
                [string]SetVirtualProperty2([string]$value) { $this.VirtualProperty2 = $value; return $this.VirtualProperty2 }
                [string]CallVirtualMethod2Base() { return ([C1ProtectedInternal]$this).VirtualMethod2() }
                [string]CallVirtualMethod2Derived() { return $this.VirtualMethod2() }

                [string]GetInstanceMemberDynamic([string]$name) { return $this.$name }
                [string]SetInstanceMemberDynamic([string]$name, [string]$value) { $this.$name = $value; return $this.$name }
                [string]CallInstanceMemberDynamic([string]$name) { return $this.$name() }
            }

            [C2ProtectedInternal]
'@

        Add-Type -TypeDefinition $c1DefinitionProtectedInternal
        Add-Type -TypeDefinition (($c1DefinitionProtectedInternal -creplace 'C1ProtectedInternal', 'C1Protected') -creplace 'protected internal', 'protected')

        $testCases = @(
            @{ accessType = 'protected'; derivedType = Invoke-Expression ($c2DefinitionProtectedInternal -creplace 'ProtectedInternal', 'Protected') }
            @{ accessType = 'protected internal'; derivedType = Invoke-Expression $c2DefinitionProtectedInternal }
        )
    }

    AfterAll {
        Set-StrictMode -Off
    }

    Context 'Derived class can access instance base class members' {

        It 'can call protected internal .NET method Object.MemberwiseClone()' {
            class CNetMethod {
                [string]$Foo
                [object]CloneIt() { return $this.MemberwiseClone() }
            }
            $c1 = [CNetMethod]::new()
            $c1.Foo = 'bar'
            $c2 = $c1.CloneIt()
            $c2.Foo | Should -Be 'bar'
        }

        It 'can call <accessType> base ctor' -TestCases $testCases {
            param($derivedType)
            $derivedType::new('foo').CtorUsed | Should -Be 'C1_ctor_1args:foo'
        }

        It 'can access <accessType> base field' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.GetInstanceField() | Should -Be 'C1_InstanceField'
            $c2.SetInstanceField('foo_InstanceField') | Should -Be 'foo_InstanceField'
        }

        It 'can access <accessType> base property' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.GetInstanceProperty() | Should -Be 'C1_InstanceProperty'
            $c2.SetInstanceProperty('foo_InstanceProperty') | Should -Be 'foo_InstanceProperty'
        }

        It 'can call <accessType> base method' -TestCases $testCases {
            param($derivedType)
            $derivedType::new().CallInstanceMethod() | Should -Be 'C1_InstanceMethod'
        }

        It 'can access <accessType> virtual base property' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.GetVirtualProperty1() | Should -Be 'C1_VirtualProperty1'
            $c2.SetVirtualProperty1('foo_VirtualProperty1') | Should -Be 'foo_VirtualProperty1'
        }

        It 'can call <accessType> virtual base method' -TestCases $testCases {
            param($derivedType)
            $derivedType::new().CallVirtualMethod1() | Should -Be 'C1_VirtualMethod1'
        }
    }

    Context 'Derived class can override virtual base class members' {

        It 'can override <accessType> virtual base property' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.GetVirtualProperty2() | Should -Be 'C2_VirtualProperty2'
            $c2.SetVirtualProperty2('foo_VirtualProperty2') | Should -Be 'foo_VirtualProperty2'
        }

        It 'can override <accessType> virtual base method' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.CallVirtualMethod2Base() | Should -Be 'C1_VirtualMethod2'
            $c2.CallVirtualMethod2Derived() | Should -Be 'C2_VirtualMethod2'
        }
    }

    Context 'Derived class can access instance base class members dynamically' {

        It 'can access <accessType> base fields and properties' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.GetInstanceMemberDynamic('InstanceField') | Should -Be 'C1_InstanceField'
            $c2.GetInstanceMemberDynamic('InstanceProperty') | Should -Be 'C1_InstanceProperty'
            $c2.GetInstanceMemberDynamic('VirtualProperty1') | Should -Be 'C1_VirtualProperty1'
            $c2.SetInstanceMemberDynamic('InstanceField', 'foo1') | Should -Be 'foo1'
            $c2.SetInstanceMemberDynamic('InstanceProperty', 'foo2') | Should -Be 'foo2'
            $c2.SetInstanceMemberDynamic('VirtualProperty1', 'foo3') | Should -Be 'foo3'
        }

        It 'can call <accessType> base methods' -TestCases $testCases {
            param($derivedType)
            $c2 = $derivedType::new()
            $c2.CallInstanceMemberDynamic('InstanceMethod') | Should -Be 'C1_InstanceMethod'
            $c2.CallInstanceMemberDynamic('VirtualMethod1') | Should -Be 'C1_VirtualMethod1'
        }
    }

    Context 'Base class members are not accessible outside class scope' {

        BeforeAll {
            $instanceTest = {
                $c2 = $derivedType::new()
                { $null = $c2.InstanceField } | Should -Throw -ErrorId 'PropertyNotFoundStrict'
                { $null = $c2.InstanceProperty } | Should -Throw -ErrorId 'PropertyNotFoundStrict'
                { $null = $c2.VirtualProperty1 } | Should -Throw -ErrorId 'PropertyNotFoundStrict'
                { $c2.InstanceField = 'foo' } | Should -Throw -ErrorId 'PropertyAssignmentException'
                { $c2.InstanceProperty = 'foo' } | Should -Throw -ErrorId 'PropertyAssignmentException'
                { $c2.VirtualProperty1 = 'foo' } | Should -Throw -ErrorId 'PropertyAssignmentException'
                { $derivedType::new().InstanceMethod() } | Should -Throw -ErrorId 'MethodNotFound'
                { $derivedType::new().VirtualMethod1() } | Should -Throw -ErrorId 'MethodNotFound'
                foreach ($name in @('InstanceField', 'InstanceProperty', 'VirtualProperty1')) {
                    { $null = $c2.$name } | Should -Throw -ErrorId 'PropertyNotFoundStrict'
                    { $c2.$name = 'foo' } | Should -Throw -ErrorId 'PropertyAssignmentException'
                }
                foreach ($name in @('InstanceMethod', 'VirtualMethod1')) {
                    { $c2.$name() } | Should -Throw -ErrorId 'MethodNotFound'
                }
            }
            $c3UnrelatedType = Invoke-Expression @"
                class C3Unrelated {
                    [void]RunInstanceTest([type]`$derivedType) { $instanceTest }
                }
                [C3Unrelated]
"@
            $negativeTestCases = $testCases.ForEach({
                    $item = $_.Clone()
                    $item['scopeType'] = 'null scope'
                    $item['classScope'] = $null
                    $item
                    $item = $_.Clone()
                    $item['scopeType'] = 'unrelated class scope'
                    $item['classScope'] = $c3UnrelatedType
                    $item
                })
        }

        It 'cannot access <accessType> instance base members in <scopeType>' -TestCases $negativeTestCases {
            param($derivedType, $classScope)
            if ($null -eq $classScope) {
                $instanceTest.Invoke()
            }
            else {
                $c3 = $classScope::new()
                $c3.RunInstanceTest($derivedType)
            }
        }
    }
}
