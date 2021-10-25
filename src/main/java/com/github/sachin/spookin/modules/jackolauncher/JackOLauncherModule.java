package com.github.sachin.spookin.modules.jackolauncher;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.Spookin;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.InventoryUtils;
import com.github.sachin.spookin.utils.Items;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftSnowball;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftThrownPotion;
import org.bukkit.craftbukkit.v1_17_R1.inventory.CraftItemStack;
import org.bukkit.enchantments.Enchantment;
import org.bukkit.entity.Player;
import org.bukkit.entity.Snowball;
import org.bukkit.entity.ThrownPotion;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.entity.EntityExplodeEvent;
import org.bukkit.event.entity.EntityShootBowEvent;
import org.bukkit.event.inventory.CraftItemEvent;
import org.bukkit.event.inventory.InventoryAction;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryType;
import org.bukkit.event.inventory.PrepareItemCraftEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.inventory.CraftingInventory;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.PlayerInventory;
import org.bukkit.inventory.RecipeChoice;
import org.bukkit.inventory.ShapedRecipe;
import org.bukkit.inventory.ShapelessRecipe;

import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.inventory.meta.PotionMeta;



import net.minecraft.world.entity.projectile.EntitySnowball;

@Module(name = "jack-o-launcher")
public class JackOLauncherModule extends BaseModule implements Listener{
    
    public static final List<Integer> ING  = Arrays.asList(1,2,3,4,6,7,8,9);
    public static final Map<Snowball,ProjectileRunnable> runnables = new HashMap<>();

    public JackOLauncherModule(){
        super();
        ShapelessRecipe recipe = new ShapelessRecipe(Spookin.getKey("fireball-easy-recipe"),new ItemStack(Material.FIRE_CHARGE));
        recipe.addIngredient(Material.GUNPOWDER);
        recipe.addIngredient(new RecipeChoice.MaterialChoice(Material.COAL,Material.CHARCOAL));
        Bukkit.addRecipe(recipe);
        ShapedRecipe recipe2 = new ShapedRecipe(SConstants.LAUNCHER_RECIPE,plugin.getItemFolder().JACKOLAUNCHER);
        recipe2.shape("GG ","ODC"," S ");
        recipe2.setIngredient('G', Material.GUNPOWDER);
        recipe2.setIngredient('O', Material.OBSIDIAN);
        recipe2.setIngredient('D', Material.DISPENSER);
        recipe2.setIngredient('C', Material.CARVED_PUMPKIN);
        recipe2.setIngredient('S', Material.STICK);
        Bukkit.addRecipe(recipe2);


    }

    @EventHandler
    public void onCraft(CraftItemEvent e){
        if(Items.hasKey(e.getCurrentItem(), SConstants.LAUNCHER_KEY)){
            Advancements.awardAdvancement("craftlauncher", (Player)e.getWhoClicked());
        }
    }

    @EventHandler
    public void craftItemEvent(PrepareItemCraftEvent e){
        CraftingInventory inv = e.getInventory();
        int in = inv.first(Material.JACK_O_LANTERN);
        if(in==-1 || e.getRecipe()!= null) return;
        int explosionyeild = 0;
        boolean muffled = false;
        boolean isEnderpearl = false;
        boolean isFirecharge = false;
        boolean isSilktouch = false;
        boolean applyBoneMeal = false;
        int fortuneLevel = 0;
        ItemStack firework = null;
        ItemStack splashPotion = null;
        ItemStack lingeringPotion = null;
        boolean multiStack=false;
        for(int i : ING){
            ItemStack item = inv.getItem(i);
            if(item == null) continue;
            if(item.getAmount()!=1){
                multiStack = true;
            }
            if(item.getType()==Material.GUNPOWDER){
                explosionyeild++;
            }
            if(item.getType().toString().endsWith("WOOL")){
                muffled=true;
            }
            if(item.getType() == Material.ENDER_PEARL){
                isEnderpearl=true;
            }
            if(item.getType()==Material.FIREWORK_ROCKET){
                firework = item;
            }
            if(item.getType()==Material.FIRE_CHARGE){
                isFirecharge = true;
            }
            if(item.getType()==Material.FEATHER){
                isSilktouch = true;

            }
            if (item.getType()==Material.GOLD_NUGGET && fortuneLevel<3){
                fortuneLevel++;
            }
            if(item.getType()==Material.BONE_BLOCK){
                applyBoneMeal = true;
            }
            if(item.getType()==Material.SPLASH_POTION){
                splashPotion = item;
            }
            if(item.getType()==Material.LINGERING_POTION){
                lingeringPotion = item;
            }
        }
        if(multiStack || (explosionyeild==0 && splashPotion==null && lingeringPotion == null)) return;
        ItemStack ammo = plugin.getItemFolder().LAUNCHER_AMMO.clone();
        List<String> lore = new ArrayList<>();
        NBTItem nbti = new NBTItem(ammo);
        if(explosionyeild != 0){
            nbti.setInt(SConstants.YEILD_KEY, explosionyeild);
            lore.add(getChat("&7Explosive Power: &f"+explosionyeild));
        }
        if(fortuneLevel != 0){
            nbti.setInt(SConstants.FORTUNE_KEY, fortuneLevel);
            lore.add(getChat("&7Fortune: &f"+fortuneLevel));
        }
        if(muffled){
            nbti.setBoolean(SConstants.MUFFLED_KEY, muffled);
            lore.add(getChat("&7Muffled"));
        }
        if(applyBoneMeal){
            nbti.setBoolean(SConstants.BONEMEAL_KEY, true);
            lore.add(getChat("&7Fertilizing"));
        }
        if(isEnderpearl){
            nbti.setBoolean(SConstants.ENDERPEARL_KEY, isEnderpearl);
            lore.add(getChat("&7Enderpearl"));
        }
        if(firework!= null){
            nbti.setString(SConstants.FIREWORK_KEY, InventoryUtils.serializeItem(firework));
            lore.add(getChat("&7Firework"));
            
        }
        if(isFirecharge){
            nbti.setBoolean(SConstants.FIRECHARGE_KEY, true);
            lore.add(getChat("&7Fire Charged"));
        }
        if(isSilktouch){
            nbti.setBoolean(SConstants.SILKTOUCH_KEY, true);
            lore.add(getChat("&7Silk Touch"));
        }
        if(splashPotion != null){
            nbti.setString(SConstants.POTION_KEY, InventoryUtils.serializeItem(splashPotion));
            PotionMeta meta = (PotionMeta) splashPotion.getItemMeta();
            lore.add(getChat("&7Splash Potion: &c"+meta.getBasePotionData().getType()));

        }
        if(lingeringPotion != null){
            nbti.setString(SConstants.LINGERING_KEY, InventoryUtils.serializeItem(lingeringPotion));
            PotionMeta meta = (PotionMeta) lingeringPotion.getItemMeta();
            lore.add(getChat("&7Lingering Potion: &c"+meta.getBasePotionData().getType()));
        }
        
        ammo = nbti.getItem();
        ItemMeta meta = ammo.getItemMeta();
        meta.setLore(lore);
        ammo.setItemMeta(meta);
        ammo.setAmount(4);
        inv.setItem(0, ammo);
    }

    private String getChat(String str){
        return ChatColor.translateAlternateColorCodes('&', str);
    }

    @EventHandler
    public void onExplode(EntityExplodeEvent e){
        if(e.getEntity() instanceof Snowball){
            Snowball entity = (Snowball) e.getEntity();
            if(runnables.containsKey(entity)){
                
                ProjectileRunnable runnable = runnables.get(entity);
                ItemStack silkyBoy = new ItemStack(Material.DIAMOND_PICKAXE);
                
                boolean silk = runnable.helper.hasSilkTouch;
                int fortune = runnable.helper.fortuneLevel;
                if(!silk || fortune < 0) return;
                if(silk){
                    silkyBoy.addEnchantment(Enchantment.SILK_TOUCH,1);
                }
                silkyBoy.addEnchantment(Enchantment.LOOT_BONUS_BLOCKS, fortune);
                for(Block b : e.blockList()){
                    b.breakNaturally(silkyBoy);
                    
                }
                e.blockList().clear();
                runnables.remove(entity);
            }
        }
    }

    public static List<Block> getNearbyBlocks(Location location, int radius) {
        List<Block> blocks = new ArrayList<Block>();
        for(int x = location.getBlockX() - radius; x <= location.getBlockX() + radius; x++) {
            for(int y = location.getBlockY() - radius; y <= location.getBlockY() + radius; y++) {
                for(int z = location.getBlockZ() - radius; z <= location.getBlockZ() + radius; z++) {
                   Block block = location.getWorld().getBlockAt(x, y, z);
                   if(block.isSolid()){
                       blocks.add(location.getWorld().getBlockAt(x, y, z));
                   } 
                }
            }
        }
        return blocks;
    }



    @EventHandler
    public void onClick(PlayerInteractEvent e){
        if(e.getItem()!= null){
            if(Items.hasKey(e.getItem(), SConstants.AMMO_KEY)){e.setCancelled(true);}
            if(Items.hasKey(e.getItem(), SConstants.LAUNCHER_KEY)){

                e.setCancelled(true);
                Player player = e.getPlayer();
                if((e.getAction()==Action.RIGHT_CLICK_AIR || e.getAction()==Action.RIGHT_CLICK_BLOCK) && player.getCooldown(e.getItem().getType())==0){
                    ItemStack ammo = findAmmo(player);
                    
                    if(ammo == null) return;
                    ProjectileHelper helper = new ProjectileHelper(ammo);
                    Snowball projectile = player.launchProjectile(Snowball.class);
                    projectile.setShooter(player);
                    if(helper.fireWork != null){
                        projectile.setGravity(false);
                    }
                    // if(e.getHand()==EquipmentSlot.HAND){
                    //     player.swingMainHand();
                    // }
                    // else if(e.getHand()==EquipmentSlot.OFF_HAND){
                    //     player.swingOffHand();
                    // }
                    if(player.getGameMode()==GameMode.SURVIVAL){
                        ammo.setAmount(ammo.getAmount()-1);
                    }
                    Advancements.awardAdvancement("uselauncher",player);
                    player.setCooldown(e.getItem().getType(), 20);
                    player.getWorld().playSound(player.getLocation(), Sound.ENTITY_FIREWORK_ROCKET_LAUNCH, 0.8F, plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
                    EntitySnowball potion = ((CraftSnowball)projectile).getHandle();
                    potion.setItem(CraftItemStack.asNMSCopy(plugin.getItemFolder().LAUNCHER_ENTITY));
                    ProjectileRunnable runnable = new ProjectileRunnable(projectile,helper);
                    runnable.runTaskTimer(plugin, 0, 1);
                    runnables.put(projectile, runnable);
                }
            }
            
        }
    }

    public ItemStack findAmmo(Player player){
        PlayerInventory inv = player.getInventory();
        if(Items.hasKey(inv.getItemInOffHand(), SConstants.AMMO_KEY)) return inv.getItemInOffHand();
        else if(Items.hasKey(inv.getItemInMainHand(), SConstants.AMMO_KEY)) return inv.getItemInMainHand();
        else{
            for(int i =0; i<44;i++){
                ItemStack item = inv.getItem(i);
                if(Items.hasKey(item, SConstants.AMMO_KEY)){
                    return item;
                }
            }

        }
        return null;
    }
}
