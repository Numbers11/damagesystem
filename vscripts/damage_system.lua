    --[[
//INTRODUCTION//
The goal of this library is to provide an easy to use way to implement different damage types and resistances against them,
without or at least wth a minimum use of modifiers / custom damage events hassle.
Please note that by default, the resistances are calculated AFTER the usual reduction from magic resist and armor.
Also there is currently no UI implementation to display the custom resistance and damage values in Panorama.

//MEET&GREET//
All contributions are welcome. Many thanks to BMD, Noya, Perry and all the other helpful people from #dota2mods

//EXAMPLES//
If you for example have a npc_fireguy and want him to be immune to fire damage, deal fire damage with his auto attacks and
be weak to water, you only need to add to npc_custom_damage_units.txt.
    "npc_fireguy"
    {
        "resistances"
        {
            "fire"   "100"
            "water"  "-50"
            "earth"  "0"
            "air"    "0"
        }
        //auto attack damage type
        "damagetype" "fire"
        "amplifier" "1"
    }


////////////////////////////////////////////////////////
If you want all damage dealt by an ability to be of type X and amplify it by 2, add to npc_custom_damag_abilities.txt
    "abaddon_death_coil"
    {
        "damagetype" "X"
        "amplifier" "2"
    }


////////////////////////////////////////////////////////
An item that gives you +100 fire resistance for the duration

  "item_fire_shield"
  {
    //"ID"              "1836"
    "AbilityBehavior"       "DOTA_ABILITY_BEHAVIOR_NO_TARGET | DOTA_ABILITY_BEHAVIOR_IMMEDIATE"
    "BaseClass"           "item_datadriven"
    "AbilityTextureName"      "item_example_item"

    // Stats
    //-------------------------------------------------------------------------------------------------------------
    //"AbilityCastPoint"        "0.2"
    "AbilityCooldown"       "13.0"

    // Item Info
    //-------------------------------------------------------------------------------------------------------------
    "AbilityManaCost"       "100"
    "ItemCost"            "750"
    "ItemInitialCharges"      "0"
    "ItemDroppable"         "1"
    "ItemSellable"          "1"
    "ItemRequiresCharges"     "0"
    "ItemShareability"        "ITEM_NOT_SHAREABLE"
    "ItemDeclarations"        "DECLARE_PURCHASES_TO_TEAMMATES | DECLARE_PURCHASES_TO_SPECTATORS"
    
    "MaxUpgradeLevel"       "1"
    "ItemBaseLevel"         "1"
    
    "precache"
    {
      "particle"              "particles/frostivus_herofx/queen_shadow_strike_linear_parent.vpcf"
      "particle_folder"       "particles/units/heroes/ember_spirit"
      "soundfile"             "soundevents/game_sounds_heroes/game_sounds_abaddon.vsndevts"
    }
    "OnSpellStart"
    {
    
      "ApplyModifier"
      {
        "Target"      "CASTER"
        "ModifierName"  "modifier_item_fire_shield"
      }
    }
    
    "Modifiers"
    {
      "modifier_item_fire_shield"
      {
        "EffectName"    "particles/test_particle/damage_immunity.vpcf"
        "EffectAttachType"  "follow_origin"
        "Target"      "CASTER"
        
        "Duration" "%duration"
        "TextureName" "abaddon_aphotic_shield"
        "OnCreated"
        {
          "RunScript"
          {
            "ScriptFile"  "damage_system.lua"
            "Function"    "AddResistance"
            "value"       "%resistance_value"
            "resistance"  "fire"
          }
        }
        "OnDestroy"
        {
          "RunScript"
          {
            "ScriptFile"  "damage_system.lua"
            "Function"    "AddResistance"
            "value"       "%resistance_value * -1"
            "resistance"  "fire"
          }
        }
      }
    }
    
    // Special  
    //-------------------------------------------------------------------------------------------------------------
    "AbilitySpecial"
    {
      "01"
      {
        "var_type"        "FIELD_FLOAT"
        "duration"        "4.0"
      }
      
      "02"
      {
        "var_type"        "FIELD_INTEGER"
        "resistance_value"    "100"
      }
    }
  }


////////////////////////////////////////////////////////
Dealing fire damage from Lua
ApplyCustomDamage(target, caster, 100, DAMAGE_TYPE_PURE, "fire")

]]


if DamageSystem == nil then
    print ( '[DamageSystem] creating DamageSystem' )
    DamageSystem = {}
    DamageSystem.__index = DamageSystem
    DamageSystem.kv_abilities = LoadKeyValues("scripts/npc/npc_custom_damage_abilities.txt")
    DamageSystem.kv_units     = LoadKeyValues("scripts/npc/npc_custom_damage_units.txt")

    --this here is a dummy to check if the damage has already been parsed by our filter, it does nothing
    DamageSystem.handle = CreateItem('item_dummy_item', nil, nil):GetEntityIndex() 
    print('[DamageSystem] Dummy ability handle: ', DamageSystem.handle)
end


function DamageSystem:DamageFilter( event )
    local attacker = EntIndexToHScript(event.entindex_attacker_const)
    local victim = EntIndexToHScript(event.entindex_victim_const)
    local ability = attacker
    if event.entindex_inflictor_const then --if there is no inflictor key then it was an auto attack
        ability = EntIndexToHScript(event.entindex_inflictor_const)
    end
    print( '********damage event************' )
    for k, v in pairs(event) do
        print("DamageFilter: ",k, " ==> ", v)
    end

    if DamageSystem.handle == event.entindex_inflictor_const then --damage directly dealt with ApplyCustomDamage
       print('DamageFilter: Directly dealt from script')
       return true 
    end

    if not DamageSystem:CreateAbility(ability) then --this means we have no kv values for this ability
        print('DamageFilter: Couldnt find this ability')
        return true
    end
    
    print('DamageFilter: attack ability type:')
    print('>', ability:GetCustomDamageType(), '  - ', ability:GetCustomDamageModifier())
    print('DamageFilter: victim resistances:')
    for k,v in pairs(victim.resistances) do print('>', k,v) end
    local newdamage = event.damage * tonumber(ability:GetCustomDamageModifier())
    newdamage = newdamage - newdamage / 100 *  tonumber(victim:GetResistance(ability:GetCustomDamageType()))
    if newdamage <= 0 then
        print('DamageFilter: Damage is 0')
        return false
    end
    print('DamageFilter: Dealing damage ', newdamage)
    event.damage = newdamage
    return true 
end

function DamageSystem:CreateAbility(ability)
    --add the damage options to an ability
    if ability.custom_damage_type then
        return true
    end
    local kvblock = nil
    for k,v in pairs(self.kv_abilities) do
        if k == ability:GetName() then
            kvblock = v
            break
        end
    end  
    if not kvblock then
        print('[DamageSystem] couldnt find this ability')
        return false
    end  
    print('[DamageSystem] creating for ', ability:GetName())
    for k, v in pairs(kvblock) do
        print(k, " ==> ", v)
    end
    ability.custom_damage_type = kvblock.damagetype or ""
    ability.custom_damage_modifier = kvblock.amplifier or 1

    function ability:GetCustomDamageType()
        return ability.custom_damage_type
    end

    function ability:SetCustomDamageType(value)
        ability.custom_damage_type = value
    end   

    function ability:GetCustomDamageModifier()
        return ability.custom_damage_modifier
    end

    function ability:SetCustomDamageModifier(value)
        ability.custom_damage_modifier = value
    end      
    PrintTable(ability)
    return true
end

function DamageSystem:CreateResistances(npc)
    --add the resistance functions and values to a unit
    if npc.resistances ~= nil then
        return true
    end
    local kvblock = nil
    for k,v in pairs(self.kv_units) do
        if k == npc:GetName() then
            kvblock = v
            break
        end
    end
    if not kvblock then
        print('[DamageSystem] couldnt find this unit')
        return false
    end
    print('[DamageSystem] creating for ', npc:GetName())
    for k, v in pairs(kvblock) do
        print(k, " ==> ", v)
    end

    npc.resistances = kvblock.resistances or {}
    npc.custom_damage_type = kvblock.damagetype or ""
    npc.custom_damage_modifier = kvblock.amplifier or 1

    function npc:AddResistance(resistance, value)
        npc.resistances[resistance] = npc.resistances[resistance] + value
    end

    function npc:SetResistance(resistance, value)
        npc.resistances[resistance] = value
    end

    function npc:GetResistance(resistance)
        return npc.resistances[resistance] or 0
    end

    function npc:GetCustomDamageType()
        return npc.custom_damage_type
    end

    function npc:SetCustomDamageType(value)
        npc.custom_damage_type = value
    end   

    function npc:GetCustomDamageModifier()
        return npc.custom_damage_modifier or 1
    end

    function npc:SetCustomDamageModifier(value)
        npc.custom_damage_modifier = value
    end      
    return true
end

--damage dealing function for RunScript calls
function ApplyCustomDamage(victim, attacker, damage, damagetype, customdamagetype)
    --print('DamageFilter: victim resistances:')
    --for k,v in pairs(victim.resistances) do print(k,v) end
    --EntIndexToHScript(DamageSystem.handle)
    local newdamage = damage - damage / 100 *  tonumber(victim:GetResistance(customdamagetype))
    local damageTable = {
        victim = victim,
        attacker = attacker,
        damage = newdamage,
        damage_type = damagetype  ,
        ability = EntIndexToHScript(DamageSystem.handle)
    }
    print('[DamageSystem] Dealing ', customdamagetype, ' damage ', newdamage)
    ApplyDamage(damageTable)   
end

--add/substract resistance function to use with modifiers
function AddResistance(event)
    --for k, v in pairs(event) do
    --    print("AddResistance: ",k, " ==> ", v)
    --end
    local unit = event.target--= event.unit
    if unit.resistances then
        print('[DamageSystem] changing ', event.resistance, ' | ', unit:GetResistance(event.resistance), ' ==> ', unit:GetResistance(event.resistance) + event.value)
        unit:AddResistance(event.resistance, event.value)
    end
end