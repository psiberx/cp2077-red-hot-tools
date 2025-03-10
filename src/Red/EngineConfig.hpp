#pragma once

namespace Red
{
enum class EngineConfigVarType : uint8_t
{
    Bool,
    Int32,
    Float,
    String,
    Color,
};

template<typename T>
struct EngineConfigVarTypeMapping : public std::false_type {};

template<>
struct EngineConfigVarTypeMapping<bool> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::Bool;
};

template<>
struct EngineConfigVarTypeMapping<int32_t> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::Int32;
};

template<>
struct EngineConfigVarTypeMapping<uint32_t> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::Int32;
};

template<>
struct EngineConfigVarTypeMapping<float> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::Float;
};

template<>
struct EngineConfigVarTypeMapping<CString> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::String;
};

template<>
struct EngineConfigVarTypeMapping<Color> : public std::true_type
{
    static constexpr auto type = EngineConfigVarType::Color;
};

struct EngineConfigVar
{
    virtual ~EngineConfigVar() = 0;                                            // 00
    virtual bool GetValueString(CString& aString) = 0;                         // 08
    virtual bool GetValue(void* aValue, EngineConfigVarType aType) = 0;        // 10
    virtual bool SetValueString(const CString& aString) = 0;                   // 18
    virtual bool SetValue(const void* aValue, EngineConfigVarType aType) = 0;  // 20
    virtual bool GetDefaultString(CString& aString) = 0;                       // 28
    virtual bool GetDefaultValue(void* aValue, EngineConfigVarType aType) = 0; // 30
    virtual bool GetMinValue(void* aValue, EngineConfigVarType aType) = 0;     // 38
    virtual bool GetMaxValue(void* aValue, EngineConfigVarType aType) = 0;     // 40
    virtual bool HasMinMaxConstraints() = 0;                                   // 48
    virtual bool IsNonDefault() = 0;                                           // 50
    virtual EngineConfigVarType GetType() = 0;                                 // 58
    virtual bool ResetToDefault() = 0;                                         // 60
};

struct EngineConfigStore
{
    EngineConfigVar* GetVar(const StringView& aGroupPath, const StringView& aVarName);

    HashMap<uint32_t, EngineConfigVar*> vars; // 00
    Mutex mutex;                              // 30
};
RED4EXT_ASSERT_SIZE(EngineConfigStore, 0x58);
RED4EXT_ASSERT_OFFSET(EngineConfigStore, vars, 0x0);
RED4EXT_ASSERT_OFFSET(EngineConfigStore, mutex, 0x30);

struct EngineConfig
{
    EngineConfigVar* GetVar(const StringView& aGroupPathPath, const StringView& aVarName);

    template<typename T>
    requires EngineConfigVarTypeMapping<T>::value
    T GetValue(const StringView& aGroupPath, const StringView& aVarName)
    {
        auto var = GetVar(aGroupPath, aVarName);

        if (!var)
            return {};

        if (var->GetType() != EngineConfigVarTypeMapping<T>::type)
            return {};

        T value;
        var->GetValue(&value, EngineConfigVarTypeMapping<T>::type);

        return value;
    }

    template<typename T>
    requires EngineConfigVarTypeMapping<T>::value
    void SetValue(const StringView& aGroupPath, const StringView& aVarName, const T& aValue)
    {
        auto var = GetVar(aGroupPath, aVarName);

        if (!var)
            return;

        if (var->GetType() != EngineConfigVarTypeMapping<T>::type)
            return;

        var->SetValue(&aValue, EngineConfigVarTypeMapping<T>::type);
    }

    static EngineConfig* Get();

    uint64_t unk00;             // 00
    uint64_t unk08;             // 08
    EngineConfigStore* store;   // 10
    uint64_t unk18;             // 18
    uint64_t unk20;             // 20
    uint8_t unk28;              // 28
    uint8_t unk29[0x3C - 0x29]; // 29
    uint32_t unk3C;             // 3C
    uint64_t unk40;             // 40
    Mutex mutex;                // 48
    uint8_t unk70;              // 70
};
RED4EXT_ASSERT_SIZE(EngineConfig, 0x78);
RED4EXT_ASSERT_OFFSET(EngineConfig, store, 0x10);
RED4EXT_ASSERT_OFFSET(EngineConfig, mutex, 0x48);
}

namespace Raw::EngineConfigStore
{
constexpr auto GetVar = Core::RawFunc<
    /* addr = */ Red::AddressLib::EngineConfigStore_GetVar,
    /* type = */ Red::EngineConfigVar* (*)(Red::EngineConfigStore* aStore, const Red::StringView& aGroupPath,
                                           const Red::StringView& aVarName)>();
}

namespace Raw::EngineConfig
{
constexpr auto GetInstance = Core::RawFunc<
    /* addr = */ Red::AddressLib::EngineConfig_GetInstance,
    /* type = */ Red::EngineConfig* (*)()>();
}
