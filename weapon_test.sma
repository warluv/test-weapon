#pragma compress 1

#include <amxmodx>
#include <reapi>

#pragma semicolon 1

const MAX_REFERENCE_LENGTH = 32;
const MAX_PAGE_ITEMS = 7;

enum _:WeaponData
{
    Weapon_Reference[MAX_REFERENCE_LENGTH],
    Weapon_Name[MAX_NAME_LENGTH],
    bool:Weapon_Malee,
    Weapon_ViewModel[MAX_RESOURCE_PATH_LENGTH],
    Weapon_PlayerModel[MAX_RESOURCE_PATH_LENGTH],
    Weapon_WorldModel[MAX_RESOURCE_PATH_LENGTH],
    Weapon_CustomId,
};

new Array:g_aWeapons;

new g_iMenuPage[MAX_PLAYERS + 1];
new Array:g_aMenuItems[MAX_PLAYERS + 1];

new const WEAPON_MENU_ID[] = "WeaponMenu";

public plugin_precache()
{
    register_plugin("Weapon Test", "1.0.0", "WarBans");

    g_aWeapons = ArrayCreate(WeaponData, 0);

    for (new i = 1; i <= MaxClients; i++)
        g_aMenuItems[i] = ArrayCreate(1, 0);

    AddWeapons();
}

public plugin_init() 
{
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "@CBasePlayerWeapon_DefaultDeploy_Pre", false);
    RegisterHookChain(RG_CWeaponBox_SetModel, "@CWeaponBox_SetModel_Pre", false);

    register_clcmd("weapon_menu", "@Command_WeaponMenu");

    register_menucmd(register_menuid(WEAPON_MENU_ID), 1023, "@HandleWeapon_Menu"); 
}

@CBasePlayerWeapon_DefaultDeploy_Pre(id, viewModel[], weaponModel[], anim, animExt[], skipLocal)
{
    new impulse = get_entvar(id, var_impulse);

    if (!impulse)
        return;

    new data[WeaponData];
    ArrayGetArray(g_aWeapons, impulse, data);

    if (data[Weapon_ViewModel][0])
        SetHookChainArg(2, ATYPE_STRING, data[Weapon_ViewModel]);

    if (data[Weapon_PlayerModel][0])
        SetHookChainArg(3, ATYPE_STRING, data[Weapon_PlayerModel]);
}

@CWeaponBox_SetModel_Pre(id, model[])
{
    new data[WeaponData];
    new item;
    new impulse;

    for (new InventorySlotType:i = PRIMARY_WEAPON_SLOT; i <= PISTOL_SLOT; i++)
    {
        item = get_member(id, m_WeaponBox_rgpPlayerItems, i);

        if (is_nullent(item))
            continue;

        impulse = get_entvar(item, var_impulse);

        if (!impulse)
            continue;

        ArrayGetArray(g_aWeapons, impulse, data);

        SetHookChainArg(2, ATYPE_STRING, data[Weapon_WorldModel]);
        break;
    }
}

@Command_WeaponMenu(id)
{
    WeaponMenu_Show(id);
    return PLUGIN_HANDLED;
}

WeaponMenu_Show(id, page = 0)
{
    if (page < 0)
        return;

    ArrayClear(g_aMenuItems[id]);

    new weaponsNum = ArraySize(g_aWeapons);
    new data[WeaponData];

    for (new i = 1; i < weaponsNum; i++)
    {
        ArrayPushCell(g_aMenuItems[id], i);
    }

    new itemNum = ArraySize(g_aMenuItems[id]);
    new bool:singlePage = bool:(itemNum < 10);
    new itemPerPage = singlePage ? 9 : MAX_PAGE_ITEMS;
    new i = min(page * itemPerPage, itemNum);
    new start = i - (i % itemPerPage);
    new end = min(start + itemPerPage, itemNum);

    g_iMenuPage[id] = start / itemPerPage;

    new isAlive = is_user_alive(id);
    new keys;
    new len;
    new index;
    new item;
    new text[MAX_MENU_LENGTH];

    if (singlePage)
        len += formatex(text[len], charsmax(text) - len, "\yВыберите оружие^n^n");
    else
        len += formatex(text[len], charsmax(text) - len, "\yВыберите оружие \r%d/%d^n^n", g_iMenuPage[id] + 1, ((itemNum - 1) / itemPerPage) + 1);
    
    for (i = start; i < end; i++)
    {
        index = ArrayGetCell(g_aMenuItems[id], i);
        ArrayGetArray(g_aWeapons, index, data);
        
        if (isAlive)
        {
            len += formatex(text[len], charsmax(text) - len, "\r%d. \w%s^n", item + 1, data[Weapon_Name]);
            keys |= (1<<item);
        }
        else
            len += formatex(text[len], charsmax(text) - len, "\r%d. \d%s^n", item + 1, data[Weapon_Name]);

        item++;
    }

    if (!singlePage)
    {
        for (i = item; i < MAX_PAGE_ITEMS; i++)
            len += formatex(text[len], charsmax(text) - len, "^n");

        if (end < itemNum)
        {
            len += formatex(text[len], charsmax(text) - len, "^n\r8. \wДальше");
            keys |= MENU_KEY_8;
        }
        else if (g_iMenuPage[id])
            len += formatex(text[len], charsmax(text) - len, "^n\r8. \dДальше");

        if (g_iMenuPage[id])
        {
            len += formatex(text[len], charsmax(text) - len, "^n\r9. \wНазад", "BB_BACK");
            keys |= MENU_KEY_9;
        }
        else
            len += formatex(text[len], charsmax(text) - len, "^n\r9. \dНазад", "BB_BACK");
    }

    len += formatex(text[len], charsmax(text) - len, "^n\r0. \wВыход");
    keys |= MENU_KEY_0;

    show_menu(id, keys, text, -1, WEAPON_MENU_ID);
}

@HandleWeapon_Menu(id, key)
{
    if (key == 9)
        return PLUGIN_HANDLED;

    if (!is_user_alive(id))
        return PLUGIN_HANDLED;

    new item = ArrayGetCell(g_aMenuItems[id], g_iMenuPage[id] * MAX_PAGE_ITEMS + key);
    new data[WeaponData];

    ArrayGetArray(g_aWeapons, item, data);

    if (!data[Weapon_Malee])
    {
        item = rg_give_custom_item(id, data[Weapon_Reference], GT_DROP_AND_REPLACE, data[Weapon_CustomId]);

        if (!is_nullent(item))
        {
            new maxAmmo1 = rg_get_iteminfo(item, ItemInfo_iMaxAmmo1);

            if (maxAmmo1 != -1)
            {
                new ammoType = get_member(item, m_Weapon_iPrimaryAmmoType);

                if (ammoType != -1)
                    set_member(id, m_rgAmmo, maxAmmo1, ammoType);
            }

            new maxAmmo2 = rg_get_iteminfo(item, ItemInfo_iMaxAmmo2);

            if (maxAmmo2 != -1)
            {
                new ammoType = get_member(item, m_Weapon_iSecondaryAmmoType);

                if (ammoType != -1)
                    set_member(id, m_rgAmmo, maxAmmo2, ammoType);
            }
        }
    }
    else
    {
        rg_give_custom_item(id, data[Weapon_Reference], GT_REPLACE, data[Weapon_CustomId]);
    }

    return PLUGIN_HANDLED;
}

AddWeapons()
{
    AddWeapon("", "");
    AddWeapon("weapon_m4a1", "M4A1", _, "models/custom_test/v_m4a1.mdl", "models/custom_test/p_m4a1.mdl", "models/custom_test/w_m4a1.mdl");
    AddWeapon("weapon_ak47", "AK47", _, "models/custom_test/v_ak47.mdl", "models/custom_test/p_ak47.mdl", "models/custom_test/w_ak47.mdl");
    AddWeapon("weapon_deagle", "Deagle", _, "models/custom_test/v_deagle.mdl", "models/custom_test/p_deagle.mdl", "models/custom_test/w_deagle.mdl");
    AddWeapon("weapon_knife", "Knife", true, "models/custom_test/v_knife.mdl", "models/custom_test/p_knife.mdl");
}

AddWeapon(reference[MAX_REFERENCE_LENGTH], name[MAX_NAME_LENGTH], bool:malee = false, viewModel[MAX_RESOURCE_PATH_LENGTH] = "", playerModel[MAX_RESOURCE_PATH_LENGTH] = "", worldModel[MAX_RESOURCE_PATH_LENGTH] = "")
{
    new data[WeaponData];

    data[Weapon_Reference] = reference;
    data[Weapon_Name] = name;
    data[Weapon_Malee] = malee;
    data[Weapon_ViewModel] = viewModel;
    data[Weapon_PlayerModel] = playerModel;
    data[Weapon_WorldModel] = worldModel;
    data[Weapon_CustomId] = ArraySize(g_aWeapons);

    if (data[Weapon_ViewModel][0])
    {
        if (file_exists(data[Weapon_ViewModel]))
            precache_model(data[Weapon_ViewModel]);
        else
            server_print("Нет модели: %s", data[Weapon_ViewModel])
    }

    if (data[Weapon_PlayerModel][0])
    {
        if (file_exists(data[Weapon_PlayerModel]))
            precache_model(data[Weapon_PlayerModel]);
        else
            server_print("Нет модели: %s", data[Weapon_PlayerModel])
    }

    if (data[Weapon_WorldModel][0])
    {
        if (file_exists(data[Weapon_WorldModel]))
            precache_model(data[Weapon_WorldModel]);
        else
            server_print("Нет модели: %s", data[Weapon_WorldModel])
    }

    return ArrayPushArray(g_aWeapons, data);
}

public plugin_natives()
{
    register_native("open_weapon_menu", "@native_open_weapon_menu");
}

@native_open_weapon_menu(plugin, argc)
{
    enum { arg_player = 1 };

    new player = get_param(arg_player);

    if (!is_user_connected(player))
        return false;

    WeaponMenu_Show(id);
    return true;
}
