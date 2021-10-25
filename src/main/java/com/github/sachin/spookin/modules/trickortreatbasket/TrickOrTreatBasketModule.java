package com.github.sachin.spookin.modules.trickortreatbasket;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import com.comphenix.protocol.PacketType;
import com.comphenix.protocol.ProtocolLibrary;
import com.comphenix.protocol.events.PacketAdapter;
import com.comphenix.protocol.events.PacketContainer;
import com.comphenix.protocol.events.PacketEvent;
import com.comphenix.protocol.wrappers.Pair;
import com.comphenix.protocol.wrappers.EnumWrappers.ItemSlot;
import com.github.sachin.spookin.BaseItem;
import com.github.sachin.spookin.Spookin;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.modules.scarecrow.ScareCrowModule;
import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.CustomBlockData;
import com.github.sachin.spookin.utils.InventoryUtils;
import com.github.sachin.spookin.utils.Items;
import com.github.sachin.spookin.utils.SConstants;
import com.google.common.base.Enums;
import com.google.common.base.Optional;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.Color;
import org.bukkit.FireworkEffect;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.Sound;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.entity.Arrow;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.Firework;
import org.bukkit.entity.Player;
import org.bukkit.entity.TNTPrimed;
import org.bukkit.entity.ThrownPotion;
import org.bukkit.entity.WanderingTrader;
import org.bukkit.entity.AbstractArrow.PickupStatus;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityExplodeEvent;
import org.bukkit.event.entity.EntitySpawnEvent;
import org.bukkit.event.entity.ItemSpawnEvent;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryCloseEvent;
import org.bukkit.event.player.PlayerBedLeaveEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.InventoryHolder;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.MerchantInventory;
import org.bukkit.inventory.MerchantRecipe;
import org.bukkit.inventory.ShapedRecipe;
import org.bukkit.FireworkEffect.Type;
import org.bukkit.inventory.meta.FireworkMeta;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.inventory.meta.PotionMeta;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;
import org.bukkit.util.Vector;
import org.jetbrains.annotations.NotNull;

@Module(name = "trick-or-treat-basket")
public class TrickOrTreatBasketModule extends BaseItem implements Listener{

    public static final String CONTENTS_KEY = "contents-key";
    public static final Map<Integer,UUID> entityIdMap = new HashMap<>();
    public static final NamespacedKey CONTENT_KEY  = Spookin.getKey("basket-contents-key");
    public static final String LOCKED = "locked-basket";
    public static final List<Double> randList  = Arrays.asList(0.5,0.6,0.7,0.8,0.9,0.4,0.55,0.67);
    public static final List<String> EMPTY_LORE  = Arrays.asList(ChatColor.GRAY+"Empty",ChatColor.GRAY+"Right Click in air to fill in contents");
    public static final List<Material> RANDOM_LOOT = Arrays.asList(Material.PUMPKIN_PIE,Material.CAKE,Material.DIAMOND,Material.NETHERITE_SCRAP,Material.CREEPER_HEAD,Material.ZOMBIE_HEAD,Material.WITHER_SKELETON_SKULL,Material.MUSIC_DISC_PIGSTEP);
    public static final List<Material> RANDOM_JUNK  = Arrays.asList(Material.COAL,Material.LAPIS_LAZULI,Material.REDSTONE,Material.STICK,Material.GOLD_NUGGET,Material.IRON_INGOT);
    public static final List<Material> SPAWN_EGG_LIST = Arrays.asList(Material.values()).stream().filter(m -> m.toString().endsWith("_SPAWN_EGG")).collect(Collectors.toList());


    public TrickOrTreatBasketModule(){
        super();
        ShapedRecipe recipe = new ShapedRecipe(SConstants.BASKET_RECIPE, this.item);
        
        recipe.shape("OPO","PCP","OPO");
        recipe.setIngredient('O', Material.ORANGE_DYE);
        recipe.setIngredient('P', Material.PAPER);
        recipe.setIngredient('C', Material.CHEST);
        Bukkit.addRecipe(recipe);

        ProtocolLibrary.getProtocolManager().addPacketListener(new PacketAdapter(plugin,PacketType.Play.Server.ENTITY_EQUIPMENT) {
            @Override
            public void onPacketSending(PacketEvent e) {
                PacketContainer packet = e.getPacket();
                int entityId = packet.getIntegers().read(0);    
                if(entityIdMap.containsKey(entityId)){
                    Entity en = Bukkit.getEntity(entityIdMap.get(entityId));
                    if(en != null && !en.isDead() && en instanceof WanderingTrader){
                        WanderingTrader trader = (WanderingTrader) en;
                        
                        List<Pair<ItemSlot,ItemStack>> pairs = new ArrayList<>();
                        pairs.add(new Pair<>(ItemSlot.MAINHAND,trader.getActiveItem()));
                        if(trader.getPotionEffect(PotionEffectType.INVISIBILITY) != null){
                            pairs.add(new Pair<>(ItemSlot.HEAD,null));
                        }
                        else{
                            pairs.add(new Pair<>(ItemSlot.HEAD,Spookin.getPlugin().getItemFolder().WITCH_HAT));
                        }
                        packet.getSlotStackPairLists().write(0, pairs);
                    }
                }
            }
        });
    }



    @EventHandler
    public void onTrade(InventoryClickEvent e){
        if(e.getInventory().getHolder() instanceof WanderingTrader){
            MerchantInventory inv = (MerchantInventory) e.getInventory();
            ItemStack s0 = inv.getItem(0);
            ItemStack s1 = inv.getItem(1);
            if(s0 != null && s1 != null && s0.getType()==Material.EMERALD && s1.getType()==Material.CARVED_PUMPKIN){
                inv.setItem(2, getRandomizedBasket());
            }
        }
    }

    @SuppressWarnings("deprecation")
    public ItemStack getRandomizedBasket(){
        List<ItemStack> items = new ArrayList<>();
        Random rand = plugin.RANDOM;
        boolean hastnt = false;
        boolean hasegg = false;
        for(int i = 0;i<9;i++){
            ItemStack item = null;
            
            if(rand.nextInt(10) ==1){
                item = new ItemStack(Material.FIREWORK_ROCKET);
                FireworkMeta fireworkMeta = (FireworkMeta) item.getItemMeta();
                FireworkEffect.Builder builder = FireworkEffect.builder();
                for(int a=0;a<ThreadLocalRandom.current().nextInt(2, 8);a++){
                    
                    builder.with(getRandomEnum(Type.class))
                    .withColor(Color.fromRGB(rand.nextInt(254), rand.nextInt(254), rand.nextInt(254)))
                    .withFade(Color.fromRGB(rand.nextInt(254), rand.nextInt(254), rand.nextInt(254)));
                    
                }
                fireworkMeta.addEffect(builder.build());
                item.setItemMeta(fireworkMeta);
            }
            if(rand.nextInt(20) == 1){
                if(rand.nextInt(2) == 1){
                    item = new ItemStack(Material.SPLASH_POTION);
                }
                else{
                    item = new ItemStack(Material.LINGERING_POTION);
                }
                PotionMeta potionMeta = (PotionMeta) item.getItemMeta();
                for(int a = 0 ; a<ThreadLocalRandom.current().nextInt(1, 3);a++){
                    PotionEffect effect = new PotionEffect(Arrays.asList(PotionEffectType.values()).get(rand.nextInt(PotionEffectType.values().length)), 30, 1);
                    potionMeta.addCustomEffect(effect, true);
                }
                item.setItemMeta(potionMeta);
            }
            if(rand.nextInt(60) == 1 && !hastnt){
                hastnt = true;
                item = new ItemStack(Material.TNT);
            }
            if (item == null && rand.nextInt(2) == 1){
                item = new ItemStack(RANDOM_JUNK.get(rand.nextInt(RANDOM_JUNK.size())),ThreadLocalRandom.current().nextInt(1, 10));
            }
            if(rand.nextInt(20) == 1 && !hasegg){
                hasegg=true;
                item = new ItemStack(SPAWN_EGG_LIST.get(rand.nextInt(SPAWN_EGG_LIST.size())));

            }
            if(rand.nextInt(50) == 1){
                item = new ItemStack(RANDOM_LOOT.get(rand.nextInt(RANDOM_LOOT.size())));
            }

            if(rand.nextInt(20) == 1){
                List<ItemStack> list= Arrays.asList(plugin.getItemFolder().CANDY,plugin.getItemFolder().CANDY_BAR,plugin.getItemFolder().SWIRLY_POP);
                
                item = list.get(rand.nextInt(list.size()));
                item.setAmount(ThreadLocalRandom.current().nextInt(1, 10));
            }
            items.add(item);
        }
        if(hastnt){
            items.clear();
            for(int a=0;a<8;a++){
                items.add(null);
            }
            items.add(new ItemStack(Material.TNT));
        }
        ItemStack basket = this.item.clone();
        NBTItem nbti = new NBTItem(basket);
        nbti.setString("random-uuid", UUID.randomUUID().toString());
        nbti.setString(LOCKED, "true");
        nbti.setString(CONTENTS_KEY, InventoryUtils.itemStackListToBase64(items));
        basket = nbti.getItem();
        ItemMeta meta = basket.getItemMeta();
        meta.setLore(Arrays.asList(ChatColor.GRAY+"??????",ChatColor.GRAY+"Break as a block to check whats inside"));
        basket.setItemMeta(meta);
        return basket;
    }

    @EventHandler
    public void onSpawn(EntitySpawnEvent e){
        if(e.getEntity() instanceof WanderingTrader){
            WanderingTrader trader = (WanderingTrader) e.getEntity();
            entityIdMap.put(trader.getEntityId(), trader.getUniqueId());
            trader.getEquipment().setHelmet(plugin.getItemFolder().WITCH_HAT);
            List<MerchantRecipe> recipes = new ArrayList<>();
            for(MerchantRecipe r : trader.getRecipes()){
                recipes.add(r);
            }
            MerchantRecipe recipe1 = new MerchantRecipe(getRandomizedBasket(), 2);
            recipe1.addIngredient(new ItemStack(Material.EMERALD));
            recipe1.addIngredient(new ItemStack(Material.CARVED_PUMPKIN));
            recipes.add(recipe1);

            ScareCrowModule module = (ScareCrowModule) plugin.getModuleManager().getModuleFromName("scarecrow");
            if(module != null){
                MerchantRecipe recipe = new MerchantRecipe(module.getItem(),1);
                recipe.addIngredient(new ItemStack(Material.EMERALD,10));
                recipe.addIngredient(new ItemStack(Material.CARVED_PUMPKIN));
                recipes.add(recipe);
            }
            MerchantRecipe hatrecipe = new MerchantRecipe(plugin.getItemFolder().WITCH_HAT,2);
            hatrecipe.addIngredient(new ItemStack(Material.EMERALD,5));
            recipes.add(hatrecipe);
            trader.setRecipes(recipes);
        }
    }


    public <T extends Enum<T>> T getRandomEnum(Class<T> clazz){
        return Arrays.asList(clazz.getEnumConstants()).get(plugin.RANDOM.nextInt(clazz.getEnumConstants().length));
    }


    @EventHandler
    public void onHeadDrops(ItemSpawnEvent e){
        if(e.getEntity().getItemStack().getType() == Material.PLAYER_HEAD || e.getEntity().getItemStack().getType() == Material.PLAYER_WALL_HEAD){
            CustomBlockData data = new CustomBlockData(e.getEntity().getLocation());
            if(data.has(CONTENT_KEY, PersistentDataType.STRING)){
                e.getEntity().remove();
                World world = e.getEntity().getWorld();
                Location loc = e.getEntity().getLocation().clone();
                dropItems(world, loc, InventoryUtils.base64ToItemStackArray(data.get(CONTENT_KEY, PersistentDataType.STRING)));
                data.remove(CONTENT_KEY);
            }
        }
    }

    @EventHandler
    public void onBedLeave(PlayerBedLeaveEvent e){
        e.getPlayer().addPotionEffect(new PotionEffect(PotionEffectType.BLINDNESS,30,1,false,false));
    }

    @EventHandler
    public void onExplode(EntityExplodeEvent e){
        for(Block b : e.blockList()){
            CustomBlockData data = new CustomBlockData(b.getLocation());
            if(data.has(CONTENT_KEY, PersistentDataType.STRING)){
                b.setType(Material.AIR);
                dropItems(b.getWorld(), b.getLocation().add( 0.5, 0.5, 0.5), InventoryUtils.base64ToItemStackArray(data.get(CONTENT_KEY, PersistentDataType.STRING)));
                data.remove(CONTENT_KEY);
            }
        }
    }
    
    public void dropItems(World world,Location loc,ItemStack[] items){
        boolean tntUsed = false;
        for(ItemStack i : items){
    
            if(i==null || i.getType().isAir()) continue;
            int amount = i.getAmount();
            Material mat = i.getType();
            if(amount<5 && mat==Material.FIREWORK_ROCKET){
                for(int a=0;a<amount;a++){
                    FireworkMeta meta = (FireworkMeta) i.getItemMeta();
                    Firework firework = world.spawn(loc, Firework.class);
                    FireworkMeta fireworkMeta = firework.getFireworkMeta();
                    fireworkMeta.addEffects(meta.getEffects());
                    firework.setFireworkMeta(fireworkMeta);
                }
            }   
            else if(amount == 1 && mat.toString().endsWith("_SPAWN_EGG")){
                Optional<EntityType> type = Enums.getIfPresent(EntityType.class, mat.toString().replace("_SPAWN_EGG", ""));
                if(type.isPresent()){
                    world.spawnEntity(loc, type.get());
                }
            }
            else if(amount < 10 && mat==Material.TIPPED_ARROW){
                PotionMeta meta = (PotionMeta) i.getItemMeta();
                
                for(int a =0;a<amount;a++){
                    Arrow arrow = world.spawnArrow(loc, BlockFace.UP.getDirection(), 1F, 10F);
                    arrow.setBasePotionData(meta.getBasePotionData());    
                    arrow.setPickupStatus(PickupStatus.ALLOWED);
                    arrow.setKnockbackStrength(1);
                    arrow.setDamage(2);
                }
            }
            else if(amount < 10 && mat==Material.ARROW){
                for(int a =0;a<amount;a++){
                    Arrow arrow = world.spawnArrow(loc, BlockFace.UP.getDirection(), 1F, 10F);
                    arrow.setPickupStatus(PickupStatus.ALLOWED);
                    arrow.setDamage(2);
                }
            }
            else if(amount==1 && mat==Material.TNT && !tntUsed){
                tntUsed = true;
                TNTPrimed tnt = world.spawn(loc, TNTPrimed.class);
                world.playSound(loc, Sound.ENTITY_TNT_PRIMED, 1F,  plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
                tnt.setFuseTicks(20);
            }
            else if(mat==Material.SPLASH_POTION || mat==Material.LINGERING_POTION){
                ThrownPotion potion = world.spawn(loc, ThrownPotion.class);
                potion.setItem(i);
                potion.setVelocity(new Vector(0, randList.get(plugin.RANDOM.nextInt(8)), 0));
            }
            else{
                world.dropItem(loc, i);
            } 
        }
    }

    @EventHandler
    public void onHeadBreak(BlockBreakEvent e){
        if(e.getBlock().getType() == Material.PLAYER_HEAD || e.getBlock().getType() == Material.PLAYER_WALL_HEAD){
            Location loc = e.getBlock().getLocation().clone();
            CustomBlockData data = new CustomBlockData(loc);
            if(data.has(CONTENT_KEY, PersistentDataType.STRING)){
                Advancements.awardAdvancement("trickortreat", e.getPlayer());
            }
            if(e.getPlayer().getGameMode()==GameMode.CREATIVE){
                if(data.has(CONTENT_KEY, PersistentDataType.STRING)){
                    dropItems(e.getBlock().getWorld(), loc.clone().add(0.5, 0, 0.5), InventoryUtils.base64ToItemStackArray(data.get(CONTENT_KEY, PersistentDataType.STRING)));
                    data.remove(CONTENT_KEY);
                }
            }
        }
    }
    // /give @p minecraft:player_head{display:{Name:"{\"text\":\"Trick or Treat Basket\"}"},SkullOwner:{Id:[I;1212044998,155534855,-1925575840,-1865534210],Properties:{textures:[{Value:"eyJ0ZXh0dXJlcyI6eyJTS0lOIjp7InVybCI6Imh0dHA6Ly90ZXh0dXJlcy5taW5lY3JhZnQubmV0L3RleHR1cmUvZTUwZjcxMmU4NzdkZmQ5MTBjOTdmMzgxOWEyMDBhMDVkNDllZTZiODNiNTkyNjg2ZTA5OWI5ZWNkNDQzZjIyOCJ9fX0="}]}}} 1

    @EventHandler
    public void onInteract(PlayerInteractEvent e){
        Player player = e.getPlayer();
        if(Items.hasKey(e.getItem(), "witch-hat")){
            if(e.getAction()==Action.RIGHT_CLICK_AIR && player.getInventory().getItem(EquipmentSlot.HEAD) == null){
                player.getInventory().setItem(e.getHand(), null);
                player.getInventory().setItem(EquipmentSlot.HEAD,plugin.getItemFolder().WITCH_HAT);
                return;
            }
        }
        if(isSimilar(e.getItem())){
            NBTItem nbti = new NBTItem(e.getItem());
            if(e.getAction()==Action.RIGHT_CLICK_AIR && e.getHand()==EquipmentSlot.HAND){
                if(e.getItem().getAmount()!=1){
                    player.sendMessage(ChatColor.RED+"Can't open a stacked basket");
                    return;
                }
                if(nbti.hasKey(LOCKED)){
                    player.sendMessage(ChatColor.translateAlternateColorCodes('&', "&cBreak the basket as block to open it"));
                    return;
                }
                TOTInv inv = new TOTInv(player);
                inv.open();
            }
        }
    }

    @EventHandler
    public void onPlace(BlockPlaceEvent e){
        if(isSimilar(e.getItemInHand())){
            Block block = e.getBlock();
            NBTItem nbti = new NBTItem(e.getItemInHand());
            if(nbti.hasKey(CONTENTS_KEY)){
                CustomBlockData data = new CustomBlockData(block.getLocation());
                data.set(CONTENT_KEY, PersistentDataType.STRING, nbti.getString(CONTENTS_KEY));
            }
        }
    }

    @Override
    public ItemStack getItem() {
        NBTItem nbti = new NBTItem(item.clone());
        nbti.setString("random-uuid", UUID.randomUUID().toString());
        return nbti.getItem();
    }

    @EventHandler
    public void onInventoryClick(InventoryClickEvent e){
        if(e.getInventory().getHolder() instanceof TOTInv){
            TOTInv inv = (TOTInv) e.getInventory().getHolder();
            inv.onClick(e);
        }
    }

    @EventHandler
    public void onInventoryClose(InventoryCloseEvent e){
        if(e.getInventory().getHolder() instanceof TOTInv){
            TOTInv inv = (TOTInv) e.getInventory().getHolder();
            inv.close();
        }
    }


    private class TOTInv implements InventoryHolder{
        
        private final Inventory inventory;
        private final Player player;
        private final ItemStack item;

        @SuppressWarnings("deprecation")
        public TOTInv(Player player){
            this.player = player;
            this.item = player.getInventory().getItemInMainHand();
            this.inventory = Bukkit.createInventory(this,9, "Trick or Treat Basket");
            
        }

        public void open(){
            NBTItem nbti = new NBTItem(item);
            if(nbti.hasKey(CONTENTS_KEY)){
                inventory.setContents(InventoryUtils.base64ToItemStackArray(nbti.getString(CONTENTS_KEY)));
            }
            player.openInventory(inventory);
        }

        public void onClick(InventoryClickEvent e){
            if((e.getCurrentItem() != null && isSimilar(e.getCurrentItem())) || (player.getInventory().getHeldItemSlot()==e.getHotbarButton())){
                e.setCancelled(true);
            }
        }

        @SuppressWarnings("deprecation")
        public void close(){

            NBTItem nbti = new NBTItem(item);
            if(!inventory.isEmpty()){
                nbti.setString(CONTENTS_KEY, InventoryUtils.itemStackListToBase64(Arrays.asList(inventory.getContents())));
            }
            else{
                nbti.removeKey(CONTENTS_KEY);
            }
            ItemStack item = nbti.getItem();
            ItemMeta meta = item.getItemMeta();
            if(!inventory.isEmpty()){
                meta.setLore(Arrays.asList(ChatColor.GRAY+"??????",ChatColor.GRAY+"Break as a block to check whats inside"));
            }
            else{
                meta.setLore(EMPTY_LORE);
            }
            item.setItemMeta(meta);
            item.setAmount(1);
            player.getInventory().setItemInMainHand(item);
        }

        @Override
        public @NotNull Inventory getInventory() {
            return inventory;
        }
    }
}
