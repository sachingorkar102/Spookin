package net.minecraft.world.entity;

import com.google.common.base.Objects;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import com.mojang.datafixers.util.Pair;
import com.mojang.serialization.DataResult;
import com.mojang.serialization.Dynamic;
import com.mojang.serialization.DynamicOps;
import java.util.Collection;
import java.util.ConcurrentModificationException;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Random;
import java.util.UUID;
import java.util.function.Predicate;
import javax.annotation.Nullable;
import net.minecraft.BlockUtil;
import net.minecraft.advancements.CriteriaTriggers;
import net.minecraft.commands.arguments.EntityAnchorArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.NonNullList;
import net.minecraft.core.Vec3i;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ItemParticleOption;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.NbtOps;
import net.minecraft.nbt.Tag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientboundAddMobPacket;
import net.minecraft.network.protocol.game.ClientboundAnimatePacket;
import net.minecraft.network.protocol.game.ClientboundEntityEventPacket;
import net.minecraft.network.protocol.game.ClientboundSetEquipmentPacket;
import net.minecraft.network.protocol.game.ClientboundTakeItemEntityPacket;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerChunkCache;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.stats.Stats;
import net.minecraft.tags.BlockTags;
import net.minecraft.tags.EntityTypeTags;
import net.minecraft.tags.FluidTags;
import net.minecraft.tags.ItemTags;
import net.minecraft.tags.Tag;
import net.minecraft.util.Mth;
import net.minecraft.world.Difficulty;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.damagesource.CombatRules;
import net.minecraft.world.damagesource.CombatTracker;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.EntityDamageSource;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffectUtil;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.ai.Brain;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeMap;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.attributes.DefaultAttributes;
import net.minecraft.world.entity.ai.targeting.TargetingConditions;
import net.minecraft.world.entity.animal.Wolf;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.projectile.AbstractArrow;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.ElytraItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.UseAnim;
import net.minecraft.world.item.alchemy.PotionUtils;
import net.minecraft.world.item.enchantment.EnchantmentHelper;
import net.minecraft.world.item.enchantment.Enchantments;
import net.minecraft.world.item.enchantment.FrostWalkerEnchantment;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.CollisionGetter;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.ItemLike;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.BedBlock;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.HoneyBlock;
import net.minecraft.world.level.block.LadderBlock;
import net.minecraft.world.level.block.PowderSnowBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.TrapDoorBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.Property;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.level.storage.loot.LootContext;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.level.storage.loot.parameters.LootContextParamSets;
import net.minecraft.world.level.storage.loot.parameters.LootContextParams;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.scores.PlayerTeam;

public abstract class LivingEntity extends Entity {
  private static final UUID SPEED_MODIFIER_SPRINTING_UUID = UUID.fromString("662A6B8D-DA3E-4C1C-8813-96EA6097278D");
  
  private static final UUID SPEED_MODIFIER_SOUL_SPEED_UUID = UUID.fromString("87f46a96-686f-4796-b035-22e16ee9e038");
  
  private static final UUID SPEED_MODIFIER_POWDER_SNOW_UUID = UUID.fromString("1eaf83ff-7207-4596-b37a-d7a07b3ec4ce");
  
  private static final AttributeModifier SPEED_MODIFIER_SPRINTING = new AttributeModifier(SPEED_MODIFIER_SPRINTING_UUID, "Sprinting speed boost", 0.30000001192092896D, AttributeModifier.Operation.MULTIPLY_TOTAL);
  
  public static final int HAND_SLOTS = 2;
  
  public static final int ARMOR_SLOTS = 4;
  
  public static final int EQUIPMENT_SLOT_OFFSET = 98;
  
  public static final int ARMOR_SLOT_OFFSET = 100;
  
  public static final int SWING_DURATION = 6;
  
  public static final int PLAYER_HURT_EXPERIENCE_TIME = 100;
  
  private static final int DAMAGE_SOURCE_TIMEOUT = 40;
  
  public static final double MIN_MOVEMENT_DISTANCE = 0.003D;
  
  public static final double DEFAULT_BASE_GRAVITY = 0.08D;
  
  public static final int DEATH_DURATION = 20;
  
  private static final int WAIT_TICKS_BEFORE_ITEM_USE_EFFECTS = 7;
  
  private static final int TICKS_PER_ELYTRA_FREE_FALL_EVENT = 10;
  
  private static final int FREE_FALL_EVENTS_PER_ELYTRA_BREAK = 2;
  
  public static final int USE_ITEM_INTERVAL = 4;
  
  private static final double MAX_LINE_OF_SIGHT_TEST_RANGE = 128.0D;
  
  protected static final int LIVING_ENTITY_FLAG_IS_USING = 1;
  
  protected static final int LIVING_ENTITY_FLAG_OFF_HAND = 2;
  
  protected static final int LIVING_ENTITY_FLAG_SPIN_ATTACK = 4;
  
  protected static final EntityDataAccessor<Byte> DATA_LIVING_ENTITY_FLAGS = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.BYTE);
  
  private static final EntityDataAccessor<Float> DATA_HEALTH_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.FLOAT);
  
  private static final EntityDataAccessor<Integer> DATA_EFFECT_COLOR_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.INT);
  
  private static final EntityDataAccessor<Boolean> DATA_EFFECT_AMBIENCE_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.BOOLEAN);
  
  private static final EntityDataAccessor<Integer> DATA_ARROW_COUNT_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.INT);
  
  private static final EntityDataAccessor<Integer> DATA_STINGER_COUNT_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.INT);
  
  private static final EntityDataAccessor<Optional<BlockPos>> SLEEPING_POS_ID = SynchedEntityData.defineId(LivingEntity.class, EntityDataSerializers.OPTIONAL_BLOCK_POS);
  
  protected static final float DEFAULT_EYE_HEIGHT = 1.74F;
  
  protected static final EntityDimensions SLEEPING_DIMENSIONS = EntityDimensions.fixed(0.2F, 0.2F);
  
  public static final float EXTRA_RENDER_CULLING_SIZE_WITH_BIG_HAT = 0.5F;
  
  private final AttributeMap attributes;
  
  private final CombatTracker combatTracker = new CombatTracker(this);
  
  private final Map<MobEffect, MobEffectInstance> activeEffects = Maps.newHashMap();
  
  private final NonNullList<ItemStack> lastHandItemStacks = NonNullList.withSize(2, ItemStack.EMPTY);
  
  private final NonNullList<ItemStack> lastArmorItemStacks = NonNullList.withSize(4, ItemStack.EMPTY);
  
  public boolean swinging;
  
  private boolean discardFriction = false;
  
  public InteractionHand swingingArm;
  
  public int swingTime;
  
  public int removeArrowTime;
  
  public int removeStingerTime;
  
  public int hurtTime;
  
  public int hurtDuration;
  
  public float hurtDir;
  
  public int deathTime;
  
  public float oAttackAnim;
  
  public float attackAnim;
  
  protected int attackStrengthTicker;
  
  public float animationSpeedOld;
  
  public float animationSpeed;
  
  public float animationPosition;
  
  public final int invulnerableDuration = 20;
  
  public final float timeOffs;
  
  public final float rotA;
  
  public float yBodyRot;
  
  public float yBodyRotO;
  
  public float yHeadRot;
  
  public float yHeadRotO;
  
  public float flyingSpeed = 0.02F;
  
  @Nullable
  protected Player lastHurtByPlayer;
  
  protected int lastHurtByPlayerTime;
  
  protected boolean dead;
  
  protected int noActionTime;
  
  protected float oRun;
  
  protected float run;
  
  protected float animStep;
  
  protected float animStepO;
  
  protected float rotOffs;
  
  protected int deathScore;
  
  protected float lastHurt;
  
  protected boolean jumping;
  
  public float xxa;
  
  public float yya;
  
  public float zza;
  
  protected int lerpSteps;
  
  protected double lerpX;
  
  protected double lerpY;
  
  protected double lerpZ;
  
  protected double lerpYRot;
  
  protected double lerpXRot;
  
  protected double lyHeadRot;
  
  protected int lerpHeadSteps;
  
  private boolean effectsDirty = true;
  
  @Nullable
  private LivingEntity lastHurtByMob;
  
  private int lastHurtByMobTimestamp;
  
  private LivingEntity lastHurtMob;
  
  private int lastHurtMobTimestamp;
  
  private float speed;
  
  private int noJumpDelay;
  
  private float absorptionAmount;
  
  protected ItemStack useItem = ItemStack.EMPTY;
  
  protected int useItemRemaining;
  
  protected int fallFlyTicks;
  
  private BlockPos lastPos;
  
  private Optional<BlockPos> lastClimbablePos = Optional.empty();
  
  @Nullable
  private DamageSource lastDamageSource;
  
  private long lastDamageStamp;
  
  protected int autoSpinAttackTicks;
  
  private float swimAmount;
  
  private float swimAmountO;
  
  protected Brain<?> brain;
  
  protected LivingEntity(EntityType<? extends LivingEntity> param_0, Level param_1) {
    super(param_0, param_1);
    this.attributes = new AttributeMap(DefaultAttributes.getSupplier(param_0));
    setHealth(getMaxHealth());
    this.blocksBuilding = true;
    this.rotA = (float)((Math.random() + 1.0D) * 0.009999999776482582D);
    reapplyPosition();
    this.timeOffs = (float)Math.random() * 12398.0F;
    setYRot((float)(Math.random() * 6.2831854820251465D));
    this.yHeadRot = getYRot();
    this.maxUpStep = 0.6F;
    NbtOps var_0 = NbtOps.INSTANCE;
    this.brain = makeBrain(new Dynamic((DynamicOps)var_0, var_0.createMap((Map)ImmutableMap.of(var_0.createString("memories"), var_0.emptyMap()))));
  }
  
  public Brain<?> getBrain() {
    return this.brain;
  }
  
  protected Brain.Provider<?> brainProvider() {
    return Brain.provider((Collection)ImmutableList.of(), (Collection)ImmutableList.of());
  }
  
  protected Brain<?> makeBrain(Dynamic<?> param_0) {
    return brainProvider().makeBrain(param_0);
  }
  
  public void kill() {
    hurt(DamageSource.OUT_OF_WORLD, Float.MAX_VALUE);
  }
  
  public boolean canAttackType(EntityType<?> param_0) {
    return true;
  }
  
  protected void defineSynchedData() {
    this.entityData.define(DATA_LIVING_ENTITY_FLAGS, Byte.valueOf((byte)0));
    this.entityData.define(DATA_EFFECT_COLOR_ID, Integer.valueOf(0));
    this.entityData.define(DATA_EFFECT_AMBIENCE_ID, Boolean.valueOf(false));
    this.entityData.define(DATA_ARROW_COUNT_ID, Integer.valueOf(0));
    this.entityData.define(DATA_STINGER_COUNT_ID, Integer.valueOf(0));
    this.entityData.define(DATA_HEALTH_ID, Float.valueOf(1.0F));
    this.entityData.define(SLEEPING_POS_ID, Optional.empty());
  }
  
  public static AttributeSupplier.Builder createLivingAttributes() {
    return AttributeSupplier.builder()
      .add(Attributes.MAX_HEALTH)
      .add(Attributes.KNOCKBACK_RESISTANCE)
      .add(Attributes.MOVEMENT_SPEED)
      .add(Attributes.ARMOR)
      .add(Attributes.ARMOR_TOUGHNESS);
  }
  
  protected void checkFallDamage(double param_0, boolean param_1, BlockState param_2, BlockPos param_3) {
    if (!isInWater())
      updateInWaterStateAndDoWaterCurrentPushing(); 
    if (!this.level.isClientSide && param_1 && this.fallDistance > 0.0F) {
      removeSoulSpeed();
      tryAddSoulSpeed();
    } 
    if (!this.level.isClientSide && this.fallDistance > 3.0F && param_1) {
      float var_0 = Mth.ceil(this.fallDistance - 3.0F);
      if (!param_2.isAir()) {
        double var_1 = Math.min((0.2F + var_0 / 15.0F), 2.5D);
        int var_2 = (int)(150.0D * var_1);
        ((ServerLevel)this.level).sendParticles((ParticleOptions)new BlockParticleOption(ParticleTypes.BLOCK, param_2), getX(), getY(), getZ(), var_2, 0.0D, 0.0D, 0.0D, 0.15000000596046448D);
      } 
    } 
    super.checkFallDamage(param_0, param_1, param_2, param_3);
  }
  
  public boolean canBreatheUnderwater() {
    return (getMobType() == MobType.UNDEAD);
  }
  
  public float getSwimAmount(float param_0) {
    return Mth.lerp(param_0, this.swimAmountO, this.swimAmount);
  }
  
  public void baseTick() {
    this.oAttackAnim = this.attackAnim;
    if (this.firstTick)
      getSleepingPos().ifPresent(this::setPosToBed); 
    if (canSpawnSoulSpeedParticle())
      spawnSoulSpeedParticle(); 
    super.baseTick();
    this.level.getProfiler().push("livingEntityBaseTick");
    boolean var_0 = this instanceof Player;
    if (isAlive())
      if (isInWall()) {
        hurt(DamageSource.IN_WALL, 1.0F);
      } else if (var_0 && !this.level.getWorldBorder().isWithinBounds(getBoundingBox())) {
        double var_1 = this.level.getWorldBorder().getDistanceToBorder(this) + this.level.getWorldBorder().getDamageSafeZone();
        if (var_1 < 0.0D) {
          double var_2 = this.level.getWorldBorder().getDamagePerBlock();
          if (var_2 > 0.0D)
            hurt(DamageSource.IN_WALL, Math.max(1, Mth.floor(-var_1 * var_2))); 
        } 
      }  
    if (fireImmune() || this.level.isClientSide)
      clearFire(); 
    boolean var_3 = (var_0 && (((Player)this).getAbilities()).invulnerable);
    if (isAlive()) {
      if (isEyeInFluid((Tag<Fluid>)FluidTags.WATER) && !this.level.getBlockState(new BlockPos(getX(), getEyeY(), getZ())).is(Blocks.BUBBLE_COLUMN)) {
        if (!canBreatheUnderwater() && !MobEffectUtil.hasWaterBreathing(this) && !var_3) {
          setAirSupply(decreaseAirSupply(getAirSupply()));
          if (getAirSupply() == -20) {
            setAirSupply(0);
            Vec3 var_4 = getDeltaMovement();
            for (int var_5 = 0; var_5 < 8; var_5++) {
              double var_6 = this.random.nextDouble() - this.random.nextDouble();
              double var_7 = this.random.nextDouble() - this.random.nextDouble();
              double var_8 = this.random.nextDouble() - this.random.nextDouble();
              this.level.addParticle((ParticleOptions)ParticleTypes.BUBBLE, getX() + var_6, getY() + var_7, getZ() + var_8, var_4.x, var_4.y, var_4.z);
            } 
            hurt(DamageSource.DROWN, 2.0F);
          } 
        } 
        if (!this.level.isClientSide && isPassenger() && getVehicle() != null && !getVehicle().rideableUnderWater())
          stopRiding(); 
      } else if (getAirSupply() < getMaxAirSupply()) {
        setAirSupply(increaseAirSupply(getAirSupply()));
      } 
      if (!this.level.isClientSide) {
        BlockPos var_9 = blockPosition();
        if (!Objects.equal(this.lastPos, var_9)) {
          this.lastPos = var_9;
          onChangedBlock(var_9);
        } 
      } 
    } 
    if (isAlive() && (isInWaterRainOrBubble() || this.isInPowderSnow)) {
      if (!this.level.isClientSide && this.wasOnFire)
        playEntityOnFireExtinguishedSound(); 
      clearFire();
    } 
    if (this.hurtTime > 0)
      this.hurtTime--; 
    if (this.invulnerableTime > 0 && !(this instanceof ServerPlayer))
      this.invulnerableTime--; 
    if (isDeadOrDying())
      tickDeath(); 
    if (this.lastHurtByPlayerTime > 0) {
      this.lastHurtByPlayerTime--;
    } else {
      this.lastHurtByPlayer = null;
    } 
    if (this.lastHurtMob != null && !this.lastHurtMob.isAlive())
      this.lastHurtMob = null; 
    if (this.lastHurtByMob != null)
      if (!this.lastHurtByMob.isAlive()) {
        setLastHurtByMob((LivingEntity)null);
      } else if (this.tickCount - this.lastHurtByMobTimestamp > 100) {
        setLastHurtByMob((LivingEntity)null);
      }  
    tickEffects();
    this.animStepO = this.animStep;
    this.yBodyRotO = this.yBodyRot;
    this.yHeadRotO = this.yHeadRot;
    this.yRotO = getYRot();
    this.xRotO = getXRot();
    this.level.getProfiler().pop();
  }
  
  public boolean canSpawnSoulSpeedParticle() {
    return (this.tickCount % 5 == 0 && (getDeltaMovement()).x != 0.0D && (getDeltaMovement()).z != 0.0D && !isSpectator() && EnchantmentHelper.hasSoulSpeed(this) && onSoulSpeedBlock());
  }
  
  protected void spawnSoulSpeedParticle() {
    Vec3 var_0 = getDeltaMovement();
    this.level.addParticle((ParticleOptions)ParticleTypes.SOUL, getX() + (this.random.nextDouble() - 0.5D) * getBbWidth(), getY() + 0.1D, getZ() + (this.random.nextDouble() - 0.5D) * getBbWidth(), var_0.x * -0.2D, 0.1D, var_0.z * -0.2D);
    float var_1 = (this.random.nextFloat() * 0.4F + this.random.nextFloat() > 0.9F) ? 0.6F : 0.0F;
    playSound(SoundEvents.SOUL_ESCAPE, var_1, 0.6F + this.random.nextFloat() * 0.4F);
  }
  
  protected boolean onSoulSpeedBlock() {
    return this.level.getBlockState(getBlockPosBelowThatAffectsMyMovement()).is((Tag)BlockTags.SOUL_SPEED_BLOCKS);
  }
  
  protected float getBlockSpeedFactor() {
    if (onSoulSpeedBlock() && EnchantmentHelper.getEnchantmentLevel(Enchantments.SOUL_SPEED, this) > 0)
      return 1.0F; 
    return super.getBlockSpeedFactor();
  }
  
  protected boolean shouldRemoveSoulSpeed(BlockState param_0) {
    return (!param_0.isAir() || isFallFlying());
  }
  
  protected void removeSoulSpeed() {
    AttributeInstance var_0 = getAttribute(Attributes.MOVEMENT_SPEED);
    if (var_0 == null)
      return; 
    if (var_0.getModifier(SPEED_MODIFIER_SOUL_SPEED_UUID) != null)
      var_0.removeModifier(SPEED_MODIFIER_SOUL_SPEED_UUID); 
  }
  
  protected void tryAddSoulSpeed() {
    if (!getBlockStateOn().isAir()) {
      int var_0 = EnchantmentHelper.getEnchantmentLevel(Enchantments.SOUL_SPEED, this);
      if (var_0 > 0 && 
        onSoulSpeedBlock()) {
        AttributeInstance var_1 = getAttribute(Attributes.MOVEMENT_SPEED);
        if (var_1 == null)
          return; 
        var_1.addTransientModifier(new AttributeModifier(SPEED_MODIFIER_SOUL_SPEED_UUID, "Soul speed boost", (0.03F * (1.0F + var_0 * 0.35F)), AttributeModifier.Operation.ADDITION));
        if (getRandom().nextFloat() < 0.04F) {
          ItemStack var_2 = getItemBySlot(EquipmentSlot.FEET);
          var_2.hurtAndBreak(1, this, param_0 -> param_0.broadcastBreakEvent(EquipmentSlot.FEET));
        } 
      } 
    } 
  }
  
  protected void removeFrost() {
    AttributeInstance var_0 = getAttribute(Attributes.MOVEMENT_SPEED);
    if (var_0 == null)
      return; 
    if (var_0.getModifier(SPEED_MODIFIER_POWDER_SNOW_UUID) != null)
      var_0.removeModifier(SPEED_MODIFIER_POWDER_SNOW_UUID); 
  }
  
  protected void tryAddFrost() {
    if (!getBlockStateOn().isAir()) {
      int var_0 = getTicksFrozen();
      if (var_0 > 0) {
        AttributeInstance var_1 = getAttribute(Attributes.MOVEMENT_SPEED);
        if (var_1 == null)
          return; 
        float var_2 = -0.05F * getPercentFrozen();
        var_1.addTransientModifier(new AttributeModifier(SPEED_MODIFIER_POWDER_SNOW_UUID, "Powder snow slow", var_2, AttributeModifier.Operation.ADDITION));
      } 
    } 
  }
  
  protected void onChangedBlock(BlockPos param_0) {
    int var_0 = EnchantmentHelper.getEnchantmentLevel(Enchantments.FROST_WALKER, this);
    if (var_0 > 0)
      FrostWalkerEnchantment.onEntityMoved(this, this.level, param_0, var_0); 
    if (shouldRemoveSoulSpeed(getBlockStateOn()))
      removeSoulSpeed(); 
    tryAddSoulSpeed();
  }
  
  public boolean isBaby() {
    return false;
  }
  
  public float getScale() {
    return isBaby() ? 0.5F : 1.0F;
  }
  
  protected boolean isAffectedByFluids() {
    return true;
  }
  
  public boolean rideableUnderWater() {
    return false;
  }
  
  protected void tickDeath() {
    this.deathTime++;
    if (this.deathTime == 20 && !this.level.isClientSide()) {
      this.level.broadcastEntityEvent(this, (byte)60);
      remove(Entity.RemovalReason.KILLED);
    } 
  }
  
  protected boolean shouldDropExperience() {
    return !isBaby();
  }
  
  protected boolean shouldDropLoot() {
    return !isBaby();
  }
  
  protected int decreaseAirSupply(int param_0) {
    int var_0 = EnchantmentHelper.getRespiration(this);
    if (var_0 > 0 && 
      this.random.nextInt(var_0 + 1) > 0)
      return param_0; 
    return param_0 - 1;
  }
  
  protected int increaseAirSupply(int param_0) {
    return Math.min(param_0 + 4, getMaxAirSupply());
  }
  
  protected int getExperienceReward(Player param_0) {
    return 0;
  }
  
  protected boolean isAlwaysExperienceDropper() {
    return false;
  }
  
  public Random getRandom() {
    return this.random;
  }
  
  @Nullable
  public LivingEntity getLastHurtByMob() {
    return this.lastHurtByMob;
  }
  
  public int getLastHurtByMobTimestamp() {
    return this.lastHurtByMobTimestamp;
  }
  
  public void setLastHurtByPlayer(@Nullable Player param_0) {
    this.lastHurtByPlayer = param_0;
    this.lastHurtByPlayerTime = this.tickCount;
  }
  
  public void setLastHurtByMob(@Nullable LivingEntity param_0) {
    this.lastHurtByMob = param_0;
    this.lastHurtByMobTimestamp = this.tickCount;
  }
  
  @Nullable
  public LivingEntity getLastHurtMob() {
    return this.lastHurtMob;
  }
  
  public int getLastHurtMobTimestamp() {
    return this.lastHurtMobTimestamp;
  }
  
  public void setLastHurtMob(Entity param_0) {
    if (param_0 instanceof LivingEntity) {
      this.lastHurtMob = (LivingEntity)param_0;
    } else {
      this.lastHurtMob = null;
    } 
    this.lastHurtMobTimestamp = this.tickCount;
  }
  
  public int getNoActionTime() {
    return this.noActionTime;
  }
  
  public void setNoActionTime(int param_0) {
    this.noActionTime = param_0;
  }
  
  public boolean shouldDiscardFriction() {
    return this.discardFriction;
  }
  
  public void setDiscardFriction(boolean param_0) {
    this.discardFriction = param_0;
  }
  
  protected void equipEventAndSound(ItemStack param_0) {
    SoundEvent var_0 = param_0.getEquipSound();
    if (param_0.isEmpty() || var_0 == null || isSpectator())
      return; 
    gameEvent(GameEvent.EQUIP);
    playSound(var_0, 1.0F, 1.0F);
  }
  
  public void addAdditionalSaveData(CompoundTag param_0) {
    param_0.putFloat("Health", getHealth());
    param_0.putShort("HurtTime", (short)this.hurtTime);
    param_0.putInt("HurtByTimestamp", this.lastHurtByMobTimestamp);
    param_0.putShort("DeathTime", (short)this.deathTime);
    param_0.putFloat("AbsorptionAmount", getAbsorptionAmount());
    param_0.put("Attributes", (Tag)getAttributes().save());
    if (!this.activeEffects.isEmpty()) {
      ListTag var_0 = new ListTag();
      for (MobEffectInstance var_1 : this.activeEffects.values())
        var_0.add(var_1.save(new CompoundTag())); 
      param_0.put("ActiveEffects", (Tag)var_0);
    } 
    param_0.putBoolean("FallFlying", isFallFlying());
    getSleepingPos().ifPresent(param_1 -> {
          param_0.putInt("SleepingX", param_1.getX());
          param_0.putInt("SleepingY", param_1.getY());
          param_0.putInt("SleepingZ", param_1.getZ());
        });
    DataResult<Tag> var_2 = this.brain.serializeStart((DynamicOps)NbtOps.INSTANCE);
    Objects.requireNonNull(LOGGER);
    var_2.resultOrPartial(LOGGER::error).ifPresent(param_1 -> param_0.put("Brain", param_1));
  }
  
  public void readAdditionalSaveData(CompoundTag param_0) {
    setAbsorptionAmount(param_0.getFloat("AbsorptionAmount"));
    if (param_0.contains("Attributes", 9) && this.level != null && !this.level.isClientSide)
      getAttributes().load(param_0.getList("Attributes", 10)); 
    if (param_0.contains("ActiveEffects", 9)) {
      ListTag var_0 = param_0.getList("ActiveEffects", 10);
      for (int var_1 = 0; var_1 < var_0.size(); var_1++) {
        CompoundTag var_2 = var_0.getCompound(var_1);
        MobEffectInstance var_3 = MobEffectInstance.load(var_2);
        if (var_3 != null)
          this.activeEffects.put(var_3.getEffect(), var_3); 
      } 
    } 
    if (param_0.contains("Health", 99))
      setHealth(param_0.getFloat("Health")); 
    this.hurtTime = param_0.getShort("HurtTime");
    this.deathTime = param_0.getShort("DeathTime");
    this.lastHurtByMobTimestamp = param_0.getInt("HurtByTimestamp");
    if (param_0.contains("Team", 8)) {
      String var_4 = param_0.getString("Team");
      PlayerTeam var_5 = this.level.getScoreboard().getPlayerTeam(var_4);
      boolean var_6 = (var_5 != null && this.level.getScoreboard().addPlayerToTeam(getStringUUID(), var_5));
      if (!var_6)
        LOGGER.warn("Unable to add mob to team \"{}\" (that team probably doesn't exist)", var_4); 
    } 
    if (param_0.getBoolean("FallFlying"))
      setSharedFlag(7, true); 
    if (param_0.contains("SleepingX", 99) && param_0
      .contains("SleepingY", 99) && param_0
      .contains("SleepingZ", 99)) {
      BlockPos var_7 = new BlockPos(param_0.getInt("SleepingX"), param_0.getInt("SleepingY"), param_0.getInt("SleepingZ"));
      setSleepingPos(var_7);
      this.entityData.set(DATA_POSE, Pose.SLEEPING);
      if (!this.firstTick)
        setPosToBed(var_7); 
    } 
    if (param_0.contains("Brain", 10))
      this.brain = makeBrain(new Dynamic((DynamicOps)NbtOps.INSTANCE, param_0.get("Brain"))); 
  }
  
  protected void tickEffects() {
    Iterator<MobEffect> var_0 = this.activeEffects.keySet().iterator();
    try {
      while (var_0.hasNext()) {
        MobEffect var_1 = var_0.next();
        MobEffectInstance var_2 = this.activeEffects.get(var_1);
        if (!var_2.tick(this, () -> onEffectUpdated(param_0, true, (Entity)null))) {
          if (!this.level.isClientSide) {
            var_0.remove();
            onEffectRemoved(var_2);
          } 
          continue;
        } 
        if (var_2.getDuration() % 600 == 0)
          onEffectUpdated(var_2, false, (Entity)null); 
      } 
    } catch (ConcurrentModificationException concurrentModificationException) {}
    if (this.effectsDirty) {
      if (!this.level.isClientSide) {
        updateInvisibilityStatus();
        updateGlowingStatus();
      } 
      this.effectsDirty = false;
    } 
    int var_3 = ((Integer)this.entityData.get(DATA_EFFECT_COLOR_ID)).intValue();
    boolean var_4 = ((Boolean)this.entityData.get(DATA_EFFECT_AMBIENCE_ID)).booleanValue();
    if (var_3 > 0) {
      boolean var_6;
      int i;
      if (isInvisible()) {
        boolean var_5 = (this.random.nextInt(15) == 0);
      } else {
        var_6 = this.random.nextBoolean();
      } 
      if (var_4)
        i = var_6 & ((this.random.nextInt(5) == 0) ? 1 : 0); 
      if (i != 0 && 
        var_3 > 0) {
        double var_7 = (var_3 >> 16 & 0xFF) / 255.0D;
        double var_8 = (var_3 >> 8 & 0xFF) / 255.0D;
        double var_9 = (var_3 >> 0 & 0xFF) / 255.0D;
        this.level.addParticle(var_4 ? (ParticleOptions)ParticleTypes.AMBIENT_ENTITY_EFFECT : (ParticleOptions)ParticleTypes.ENTITY_EFFECT, getRandomX(0.5D), getRandomY(), getRandomZ(0.5D), var_7, var_8, var_9);
      } 
    } 
  }
  
  protected void updateInvisibilityStatus() {
    if (this.activeEffects.isEmpty()) {
      removeEffectParticles();
      setInvisible(false);
    } else {
      Collection<MobEffectInstance> var_0 = this.activeEffects.values();
      this.entityData.set(DATA_EFFECT_AMBIENCE_ID, Boolean.valueOf(areAllEffectsAmbient(var_0)));
      this.entityData.set(DATA_EFFECT_COLOR_ID, Integer.valueOf(PotionUtils.getColor(var_0)));
      setInvisible(hasEffect(MobEffects.INVISIBILITY));
    } 
  }
  
  private void updateGlowingStatus() {
    boolean var_0 = isCurrentlyGlowing();
    if (getSharedFlag(6) != var_0)
      setSharedFlag(6, var_0); 
  }
  
  public double getVisibilityPercent(@Nullable Entity param_0) {
    double var_0 = 1.0D;
    if (isDiscrete())
      var_0 *= 0.8D; 
    if (isInvisible()) {
      float var_1 = getArmorCoverPercentage();
      if (var_1 < 0.1F)
        var_1 = 0.1F; 
      var_0 *= 0.7D * var_1;
    } 
    if (param_0 != null) {
      ItemStack var_2 = getItemBySlot(EquipmentSlot.HEAD);
      EntityType<?> var_3 = param_0.getType();
      if ((var_3 == EntityType.SKELETON && var_2.is(Items.SKELETON_SKULL)) || (var_3 == EntityType.ZOMBIE && var_2
        .is(Items.ZOMBIE_HEAD)) || (var_3 == EntityType.CREEPER && var_2
        .is(Items.CREEPER_HEAD)))
        var_0 *= 0.5D; 
    } 
    return var_0;
  }
  
  public boolean canAttack(LivingEntity param_0) {
    if (param_0 instanceof Player && this.level.getDifficulty() == Difficulty.PEACEFUL)
      return false; 
    return param_0.canBeSeenAsEnemy();
  }
  
  public boolean canAttack(LivingEntity param_0, TargetingConditions param_1) {
    return param_1.test(this, param_0);
  }
  
  public boolean canBeSeenAsEnemy() {
    return (!isInvulnerable() && canBeSeenByAnyone());
  }
  
  public boolean canBeSeenByAnyone() {
    return (!isSpectator() && isAlive());
  }
  
  public static boolean areAllEffectsAmbient(Collection<MobEffectInstance> param_0) {
    for (MobEffectInstance var_0 : param_0) {
      if (!var_0.isAmbient())
        return false; 
    } 
    return true;
  }
  
  protected void removeEffectParticles() {
    this.entityData.set(DATA_EFFECT_AMBIENCE_ID, Boolean.valueOf(false));
    this.entityData.set(DATA_EFFECT_COLOR_ID, Integer.valueOf(0));
  }
  
  public boolean removeAllEffects() {
    if (this.level.isClientSide)
      return false; 
    Iterator<MobEffectInstance> var_0 = this.activeEffects.values().iterator();
    boolean var_1 = false;
    while (var_0.hasNext()) {
      onEffectRemoved(var_0.next());
      var_0.remove();
      var_1 = true;
    } 
    return var_1;
  }
  
  public Collection<MobEffectInstance> getActiveEffects() {
    return this.activeEffects.values();
  }
  
  public Map<MobEffect, MobEffectInstance> getActiveEffectsMap() {
    return this.activeEffects;
  }
  
  public boolean hasEffect(MobEffect param_0) {
    return this.activeEffects.containsKey(param_0);
  }
  
  @Nullable
  public MobEffectInstance getEffect(MobEffect param_0) {
    return this.activeEffects.get(param_0);
  }
  
  public final boolean addEffect(MobEffectInstance param_0) {
    return addEffect(param_0, (Entity)null);
  }
  
  public boolean addEffect(MobEffectInstance param_0, @Nullable Entity param_1) {
    if (!canBeAffected(param_0))
      return false; 
    MobEffectInstance var_0 = this.activeEffects.get(param_0.getEffect());
    if (var_0 == null) {
      this.activeEffects.put(param_0.getEffect(), param_0);
      onEffectAdded(param_0, param_1);
      return true;
    } 
    if (var_0.update(param_0)) {
      onEffectUpdated(var_0, true, param_1);
      return true;
    } 
    return false;
  }
  
  public boolean canBeAffected(MobEffectInstance param_0) {
    if (getMobType() == MobType.UNDEAD) {
      MobEffect var_0 = param_0.getEffect();
      if (var_0 == MobEffects.REGENERATION || var_0 == MobEffects.POISON)
        return false; 
    } 
    return true;
  }
  
  public void forceAddEffect(MobEffectInstance param_0, @Nullable Entity param_1) {
    if (!canBeAffected(param_0))
      return; 
    MobEffectInstance var_0 = this.activeEffects.put(param_0.getEffect(), param_0);
    if (var_0 == null) {
      onEffectAdded(param_0, param_1);
    } else {
      onEffectUpdated(param_0, true, param_1);
    } 
  }
  
  public boolean isInvertedHealAndHarm() {
    return (getMobType() == MobType.UNDEAD);
  }
  
  @Nullable
  public MobEffectInstance removeEffectNoUpdate(@Nullable MobEffect param_0) {
    return this.activeEffects.remove(param_0);
  }
  
  public boolean removeEffect(MobEffect param_0) {
    MobEffectInstance var_0 = removeEffectNoUpdate(param_0);
    if (var_0 != null) {
      onEffectRemoved(var_0);
      return true;
    } 
    return false;
  }
  
  protected void onEffectAdded(MobEffectInstance param_0, @Nullable Entity param_1) {
    this.effectsDirty = true;
    if (!this.level.isClientSide)
      param_0.getEffect().addAttributeModifiers(this, getAttributes(), param_0.getAmplifier()); 
  }
  
  protected void onEffectUpdated(MobEffectInstance param_0, boolean param_1, @Nullable Entity param_2) {
    this.effectsDirty = true;
    if (param_1 && !this.level.isClientSide) {
      MobEffect var_0 = param_0.getEffect();
      var_0.removeAttributeModifiers(this, getAttributes(), param_0.getAmplifier());
      var_0.addAttributeModifiers(this, getAttributes(), param_0.getAmplifier());
    } 
  }
  
  protected void onEffectRemoved(MobEffectInstance param_0) {
    this.effectsDirty = true;
    if (!this.level.isClientSide)
      param_0.getEffect().removeAttributeModifiers(this, getAttributes(), param_0.getAmplifier()); 
  }
  
  public void heal(float param_0) {
    float var_0 = getHealth();
    if (var_0 > 0.0F)
      setHealth(var_0 + param_0); 
  }
  
  public float getHealth() {
    return ((Float)this.entityData.get(DATA_HEALTH_ID)).floatValue();
  }
  
  public void setHealth(float param_0) {
    this.entityData.set(DATA_HEALTH_ID, Float.valueOf(Mth.clamp(param_0, 0.0F, getMaxHealth())));
  }
  
  public boolean isDeadOrDying() {
    return (getHealth() <= 0.0F);
  }
  
  public boolean hurt(DamageSource param_0, float param_1) {
    if (isInvulnerableTo(param_0))
      return false; 
    if (this.level.isClientSide)
      return false; 
    if (isDeadOrDying())
      return false; 
    if (param_0.isFire() && hasEffect(MobEffects.FIRE_RESISTANCE))
      return false; 
    if (isSleeping() && !this.level.isClientSide)
      stopSleeping(); 
    this.noActionTime = 0;
    float var_0 = param_1;
    boolean var_1 = false;
    float var_2 = 0.0F;
    if (param_1 > 0.0F && isDamageSourceBlocked(param_0)) {
      hurtCurrentlyUsedShield(param_1);
      var_2 = param_1;
      param_1 = 0.0F;
      if (!param_0.isProjectile()) {
        Entity var_3 = param_0.getDirectEntity();
        if (var_3 instanceof LivingEntity)
          blockUsingShield((LivingEntity)var_3); 
      } 
      var_1 = true;
    } 
    this.animationSpeed = 1.5F;
    boolean var_4 = true;
    if (this.invulnerableTime > 10.0F) {
      if (param_1 <= this.lastHurt)
        return false; 
      actuallyHurt(param_0, param_1 - this.lastHurt);
      this.lastHurt = param_1;
      var_4 = false;
    } else {
      this.lastHurt = param_1;
      this.invulnerableTime = 20;
      actuallyHurt(param_0, param_1);
      this.hurtDuration = 10;
      this.hurtTime = this.hurtDuration;
    } 
    if (param_0.isDamageHelmet() && !getItemBySlot(EquipmentSlot.HEAD).isEmpty()) {
      hurtHelmet(param_0, param_1);
      param_1 *= 0.75F;
    } 
    this.hurtDir = 0.0F;
    Entity var_5 = param_0.getEntity();
    if (var_5 != null) {
      if (var_5 instanceof LivingEntity && !param_0.isNoAggro())
        setLastHurtByMob((LivingEntity)var_5); 
      if (var_5 instanceof Player) {
        this.lastHurtByPlayerTime = 100;
        this.lastHurtByPlayer = (Player)var_5;
      } else if (var_5 instanceof Wolf) {
        Wolf var_6 = (Wolf)var_5;
        if (var_6.isTame()) {
          this.lastHurtByPlayerTime = 100;
          LivingEntity var_7 = var_6.getOwner();
          if (var_7 != null && var_7.getType() == EntityType.PLAYER) {
            this.lastHurtByPlayer = (Player)var_7;
          } else {
            this.lastHurtByPlayer = null;
          } 
        } 
      } 
    } 
    if (var_4) {
      if (var_1) {
        this.level.broadcastEntityEvent(this, (byte)29);
      } else if (param_0 instanceof EntityDamageSource && ((EntityDamageSource)param_0).isThorns()) {
        this.level.broadcastEntityEvent(this, (byte)33);
      } else {
        byte var_12;
        if (param_0 == DamageSource.DROWN) {
          byte var_8 = 36;
        } else if (param_0.isFire()) {
          byte var_9 = 37;
        } else if (param_0 == DamageSource.SWEET_BERRY_BUSH) {
          byte var_10 = 44;
        } else if (param_0 == DamageSource.FREEZE) {
          byte var_11 = 57;
        } else {
          var_12 = 2;
        } 
        this.level.broadcastEntityEvent(this, var_12);
      } 
      if (param_0 != DamageSource.DROWN && (!var_1 || param_1 > 0.0F))
        markHurt(); 
      if (var_5 != null) {
        double var_13 = var_5.getX() - getX();
        double var_14 = var_5.getZ() - getZ();
        while (var_13 * var_13 + var_14 * var_14 < 1.0E-4D) {
          var_13 = (Math.random() - Math.random()) * 0.01D;
          var_14 = (Math.random() - Math.random()) * 0.01D;
        } 
        this.hurtDir = (float)(Mth.atan2(var_14, var_13) * 57.2957763671875D - getYRot());
        knockback(0.4000000059604645D, var_13, var_14);
      } else {
        this.hurtDir = ((int)(Math.random() * 2.0D) * 180);
      } 
    } 
    if (isDeadOrDying()) {
      if (!checkTotemDeathProtection(param_0)) {
        SoundEvent var_15 = getDeathSound();
        if (var_4 && var_15 != null)
          playSound(var_15, getSoundVolume(), getVoicePitch()); 
        die(param_0);
      } 
    } else if (var_4) {
      playHurtSound(param_0);
    } 
    boolean var_16 = (!var_1 || param_1 > 0.0F);
    if (var_16) {
      this.lastDamageSource = param_0;
      this.lastDamageStamp = this.level.getGameTime();
    } 
    if (this instanceof ServerPlayer) {
      CriteriaTriggers.ENTITY_HURT_PLAYER.trigger((ServerPlayer)this, param_0, var_0, param_1, var_1);
      if (var_2 > 0.0F && var_2 < 3.4028235E37F)
        ((ServerPlayer)this).awardStat(Stats.DAMAGE_BLOCKED_BY_SHIELD, Math.round(var_2 * 10.0F)); 
    } 
    if (var_5 instanceof ServerPlayer)
      CriteriaTriggers.PLAYER_HURT_ENTITY.trigger((ServerPlayer)var_5, this, param_0, var_0, param_1, var_1); 
    return var_16;
  }
  
  protected void blockUsingShield(LivingEntity param_0) {
    param_0.blockedByShield(this);
  }
  
  protected void blockedByShield(LivingEntity param_0) {
    param_0.knockback(0.5D, param_0.getX() - getX(), param_0.getZ() - getZ());
  }
  
  private boolean checkTotemDeathProtection(DamageSource param_0) {
    if (param_0.isBypassInvul())
      return false; 
    ItemStack var_0 = null;
    for (InteractionHand var_1 : InteractionHand.values()) {
      ItemStack var_2 = getItemInHand(var_1);
      if (var_2.is(Items.TOTEM_OF_UNDYING)) {
        var_0 = var_2.copy();
        var_2.shrink(1);
        break;
      } 
    } 
    if (var_0 != null) {
      if (this instanceof ServerPlayer) {
        ServerPlayer var_3 = (ServerPlayer)this;
        var_3.awardStat(Stats.ITEM_USED.get(Items.TOTEM_OF_UNDYING));
        CriteriaTriggers.USED_TOTEM.trigger(var_3, var_0);
      } 
      setHealth(1.0F);
      removeAllEffects();
      addEffect(new MobEffectInstance(MobEffects.REGENERATION, 900, 1));
      addEffect(new MobEffectInstance(MobEffects.ABSORPTION, 100, 1));
      addEffect(new MobEffectInstance(MobEffects.FIRE_RESISTANCE, 800, 0));
      this.level.broadcastEntityEvent(this, (byte)35);
    } 
    return (var_0 != null);
  }
  
  @Nullable
  public DamageSource getLastDamageSource() {
    if (this.level.getGameTime() - this.lastDamageStamp > 40L)
      this.lastDamageSource = null; 
    return this.lastDamageSource;
  }
  
  protected void playHurtSound(DamageSource param_0) {
    SoundEvent var_0 = getHurtSound(param_0);
    if (var_0 != null)
      playSound(var_0, getSoundVolume(), getVoicePitch()); 
  }
  
  public boolean isDamageSourceBlocked(DamageSource param_0) {
    Entity var_0 = param_0.getDirectEntity();
    boolean var_1 = false;
    if (var_0 instanceof AbstractArrow) {
      AbstractArrow var_2 = (AbstractArrow)var_0;
      if (var_2.getPierceLevel() > 0)
        var_1 = true; 
    } 
    if (!param_0.isBypassArmor() && isBlocking() && !var_1) {
      Vec3 var_3 = param_0.getSourcePosition();
      if (var_3 != null) {
        Vec3 var_4 = getViewVector(1.0F);
        Vec3 var_5 = var_3.vectorTo(position()).normalize();
        var_5 = new Vec3(var_5.x, 0.0D, var_5.z);
        if (var_5.dot(var_4) < 0.0D)
          return true; 
      } 
    } 
    return false;
  }
  
  private void breakItem(ItemStack param_0) {
    if (!param_0.isEmpty()) {
      if (!isSilent())
        this.level.playLocalSound(getX(), getY(), getZ(), SoundEvents.ITEM_BREAK, getSoundSource(), 0.8F, 0.8F + this.level.random.nextFloat() * 0.4F, false); 
      spawnItemParticles(param_0, 5);
    } 
  }
  
  public void die(DamageSource param_0) {
    if (isRemoved() || this.dead)
      return; 
    Entity var_0 = param_0.getEntity();
    LivingEntity var_1 = getKillCredit();
    if (this.deathScore >= 0 && var_1 != null)
      var_1.awardKillScore(this, this.deathScore, param_0); 
    if (isSleeping())
      stopSleeping(); 
    if (!this.level.isClientSide && hasCustomName())
      LOGGER.info("Named entity {} died: {}", this, getCombatTracker().getDeathMessage().getString()); 
    this.dead = true;
    getCombatTracker().recheckStatus();
    if (this.level instanceof ServerLevel) {
      if (var_0 != null)
        var_0.killed((ServerLevel)this.level, this); 
      dropAllDeathLoot(param_0);
      createWitherRose(var_1);
    } 
    this.level.broadcastEntityEvent(this, (byte)3);
    setPose(Pose.DYING);
  }
  
  protected void createWitherRose(@Nullable LivingEntity param_0) {
    if (this.level.isClientSide)
      return; 
    boolean var_0 = false;
    if (param_0 instanceof net.minecraft.world.entity.boss.wither.WitherBoss) {
      if (this.level.getGameRules().getBoolean(GameRules.RULE_MOBGRIEFING)) {
        BlockPos var_1 = blockPosition();
        BlockState var_2 = Blocks.WITHER_ROSE.defaultBlockState();
        if (this.level.getBlockState(var_1).isAir() && var_2.canSurvive((LevelReader)this.level, var_1)) {
          this.level.setBlock(var_1, var_2, 3);
          var_0 = true;
        } 
      } 
      if (!var_0) {
        ItemEntity var_3 = new ItemEntity(this.level, getX(), getY(), getZ(), new ItemStack((ItemLike)Items.WITHER_ROSE));
        this.level.addFreshEntity((Entity)var_3);
      } 
    } 
  }
  
  protected void dropAllDeathLoot(DamageSource param_0) {
    int var_2;
    Entity var_0 = param_0.getEntity();
    if (var_0 instanceof Player) {
      int var_1 = EnchantmentHelper.getMobLooting((LivingEntity)var_0);
    } else {
      var_2 = 0;
    } 
    boolean var_3 = (this.lastHurtByPlayerTime > 0);
    if (shouldDropLoot() && this.level.getGameRules().getBoolean(GameRules.RULE_DOMOBLOOT)) {
      dropFromLootTable(param_0, var_3);
      dropCustomDeathLoot(param_0, var_2, var_3);
    } 
    dropEquipment();
    dropExperience();
  }
  
  protected void dropEquipment() {}
  
  protected void dropExperience() {
    if (this.level instanceof ServerLevel && (isAlwaysExperienceDropper() || (this.lastHurtByPlayerTime > 0 && shouldDropExperience() && this.level.getGameRules().getBoolean(GameRules.RULE_DOMOBLOOT))))
      ExperienceOrb.award((ServerLevel)this.level, position(), getExperienceReward(this.lastHurtByPlayer)); 
  }
  
  protected void dropCustomDeathLoot(DamageSource param_0, int param_1, boolean param_2) {}
  
  public ResourceLocation getLootTable() {
    return getType().getDefaultLootTable();
  }
  
  protected void dropFromLootTable(DamageSource param_0, boolean param_1) {
    ResourceLocation var_0 = getLootTable();
    LootTable var_1 = this.level.getServer().getLootTables().get(var_0);
    LootContext.Builder var_2 = createLootContext(param_1, param_0);
    var_1.getRandomItems(var_2.create(LootContextParamSets.ENTITY), this::spawnAtLocation);
  }
  
  protected LootContext.Builder createLootContext(boolean param_0, DamageSource param_1) {
    LootContext.Builder var_0 = (new LootContext.Builder((ServerLevel)this.level)).withRandom(this.random).withParameter(LootContextParams.THIS_ENTITY, this).withParameter(LootContextParams.ORIGIN, position()).withParameter(LootContextParams.DAMAGE_SOURCE, param_1).withOptionalParameter(LootContextParams.KILLER_ENTITY, param_1.getEntity()).withOptionalParameter(LootContextParams.DIRECT_KILLER_ENTITY, param_1.getDirectEntity());
    if (param_0 && this.lastHurtByPlayer != null)
      var_0 = var_0.withParameter(LootContextParams.LAST_DAMAGE_PLAYER, this.lastHurtByPlayer).withLuck(this.lastHurtByPlayer.getLuck()); 
    return var_0;
  }
  
  public void knockback(double param_0, double param_1, double param_2) {
    param_0 *= 1.0D - getAttributeValue(Attributes.KNOCKBACK_RESISTANCE);
    if (param_0 <= 0.0D)
      return; 
    this.hasImpulse = true;
    Vec3 var_0 = getDeltaMovement();
    Vec3 var_1 = (new Vec3(param_1, 0.0D, param_2)).normalize().scale(param_0);
    setDeltaMovement(var_0.x / 2.0D - var_1.x, 
        
        this.onGround ? Math.min(0.4D, var_0.y / 2.0D + param_0) : var_0.y, var_0.z / 2.0D - var_1.z);
  }
  
  @Nullable
  protected SoundEvent getHurtSound(DamageSource param_0) {
    return SoundEvents.GENERIC_HURT;
  }
  
  @Nullable
  protected SoundEvent getDeathSound() {
    return SoundEvents.GENERIC_DEATH;
  }
  
  protected SoundEvent getFallDamageSound(int param_0) {
    if (param_0 > 4)
      return SoundEvents.GENERIC_BIG_FALL; 
    return SoundEvents.GENERIC_SMALL_FALL;
  }
  
  protected SoundEvent getDrinkingSound(ItemStack param_0) {
    return param_0.getDrinkingSound();
  }
  
  public SoundEvent getEatingSound(ItemStack param_0) {
    return param_0.getEatingSound();
  }
  
  public void setOnGround(boolean param_0) {
    super.setOnGround(param_0);
    if (param_0)
      this.lastClimbablePos = Optional.empty(); 
  }
  
  public Optional<BlockPos> getLastClimbablePos() {
    return this.lastClimbablePos;
  }
  
  public boolean onClimbable() {
    if (isSpectator())
      return false; 
    BlockPos var_0 = blockPosition();
    BlockState var_1 = getFeetBlockState();
    if (var_1.is((Tag)BlockTags.CLIMBABLE)) {
      this.lastClimbablePos = Optional.of(var_0);
      return true;
    } 
    if (var_1.getBlock() instanceof TrapDoorBlock && trapdoorUsableAsLadder(var_0, var_1)) {
      this.lastClimbablePos = Optional.of(var_0);
      return true;
    } 
    return false;
  }
  
  private boolean trapdoorUsableAsLadder(BlockPos param_0, BlockState param_1) {
    if (((Boolean)param_1.getValue((Property)TrapDoorBlock.OPEN)).booleanValue()) {
      BlockState var_0 = this.level.getBlockState(param_0.below());
      if (var_0.is(Blocks.LADDER) && var_0.getValue((Property)LadderBlock.FACING) == param_1.getValue((Property)TrapDoorBlock.FACING))
        return true; 
    } 
    return false;
  }
  
  public boolean isAlive() {
    return (!isRemoved() && getHealth() > 0.0F);
  }
  
  public boolean causeFallDamage(float param_0, float param_1, DamageSource param_2) {
    boolean var_0 = super.causeFallDamage(param_0, param_1, param_2);
    int var_1 = calculateFallDamage(param_0, param_1);
    if (var_1 > 0) {
      playSound(getFallDamageSound(var_1), 1.0F, 1.0F);
      playBlockFallSound();
      hurt(param_2, var_1);
      return true;
    } 
    return var_0;
  }
  
  protected int calculateFallDamage(float param_0, float param_1) {
    MobEffectInstance var_0 = getEffect(MobEffects.JUMP);
    float var_1 = (var_0 == null) ? 0.0F : (var_0.getAmplifier() + 1);
    return Mth.ceil((param_0 - 3.0F - var_1) * param_1);
  }
  
  protected void playBlockFallSound() {
    if (isSilent())
      return; 
    int var_0 = Mth.floor(getX());
    int var_1 = Mth.floor(getY() - 0.20000000298023224D);
    int var_2 = Mth.floor(getZ());
    BlockState var_3 = this.level.getBlockState(new BlockPos(var_0, var_1, var_2));
    if (!var_3.isAir()) {
      SoundType var_4 = var_3.getSoundType();
      playSound(var_4.getFallSound(), var_4.getVolume() * 0.5F, var_4.getPitch() * 0.75F);
    } 
  }
  
  public void animateHurt() {
    this.hurtDuration = 10;
    this.hurtTime = this.hurtDuration;
    this.hurtDir = 0.0F;
  }
  
  public int getArmorValue() {
    return Mth.floor(getAttributeValue(Attributes.ARMOR));
  }
  
  protected void hurtArmor(DamageSource param_0, float param_1) {}
  
  protected void hurtHelmet(DamageSource param_0, float param_1) {}
  
  protected void hurtCurrentlyUsedShield(float param_0) {}
  
  protected float getDamageAfterArmorAbsorb(DamageSource param_0, float param_1) {
    if (!param_0.isBypassArmor()) {
      hurtArmor(param_0, param_1);
      param_1 = CombatRules.getDamageAfterAbsorb(param_1, getArmorValue(), (float)getAttributeValue(Attributes.ARMOR_TOUGHNESS));
    } 
    return param_1;
  }
  
  protected float getDamageAfterMagicAbsorb(DamageSource param_0, float param_1) {
    if (param_0.isBypassMagic())
      return param_1; 
    if (hasEffect(MobEffects.DAMAGE_RESISTANCE) && param_0 != DamageSource.OUT_OF_WORLD) {
      int var_0 = (getEffect(MobEffects.DAMAGE_RESISTANCE).getAmplifier() + 1) * 5;
      int var_1 = 25 - var_0;
      float var_2 = param_1 * var_1;
      float var_3 = param_1;
      param_1 = Math.max(var_2 / 25.0F, 0.0F);
      float var_4 = var_3 - param_1;
      if (var_4 > 0.0F && var_4 < 3.4028235E37F)
        if (this instanceof ServerPlayer) {
          ((ServerPlayer)this).awardStat(Stats.DAMAGE_RESISTED, Math.round(var_4 * 10.0F));
        } else if (param_0.getEntity() instanceof ServerPlayer) {
          ((ServerPlayer)param_0.getEntity()).awardStat(Stats.DAMAGE_DEALT_RESISTED, Math.round(var_4 * 10.0F));
        }  
    } 
    if (param_1 <= 0.0F)
      return 0.0F; 
    int var_5 = EnchantmentHelper.getDamageProtection(getArmorSlots(), param_0);
    if (var_5 > 0)
      param_1 = CombatRules.getDamageAfterMagicAbsorb(param_1, var_5); 
    return param_1;
  }
  
  protected void actuallyHurt(DamageSource param_0, float param_1) {
    if (isInvulnerableTo(param_0))
      return; 
    param_1 = getDamageAfterArmorAbsorb(param_0, param_1);
    param_1 = getDamageAfterMagicAbsorb(param_0, param_1);
    float var_0 = param_1;
    param_1 = Math.max(param_1 - getAbsorptionAmount(), 0.0F);
    setAbsorptionAmount(getAbsorptionAmount() - var_0 - param_1);
    float var_1 = var_0 - param_1;
    if (var_1 > 0.0F && var_1 < 3.4028235E37F && param_0.getEntity() instanceof ServerPlayer)
      ((ServerPlayer)param_0.getEntity()).awardStat(Stats.DAMAGE_DEALT_ABSORBED, Math.round(var_1 * 10.0F)); 
    if (param_1 == 0.0F)
      return; 
    float var_2 = getHealth();
    setHealth(var_2 - param_1);
    getCombatTracker().recordDamage(param_0, var_2, param_1);
    setAbsorptionAmount(getAbsorptionAmount() - param_1);
    gameEvent(GameEvent.ENTITY_DAMAGED, param_0.getEntity());
  }
  
  public CombatTracker getCombatTracker() {
    return this.combatTracker;
  }
  
  @Nullable
  public LivingEntity getKillCredit() {
    if (this.combatTracker.getKiller() != null)
      return this.combatTracker.getKiller(); 
    if (this.lastHurtByPlayer != null)
      return (LivingEntity)this.lastHurtByPlayer; 
    if (this.lastHurtByMob != null)
      return this.lastHurtByMob; 
    return null;
  }
  
  public final float getMaxHealth() {
    return (float)getAttributeValue(Attributes.MAX_HEALTH);
  }
  
  public final int getArrowCount() {
    return ((Integer)this.entityData.get(DATA_ARROW_COUNT_ID)).intValue();
  }
  
  public final void setArrowCount(int param_0) {
    this.entityData.set(DATA_ARROW_COUNT_ID, Integer.valueOf(param_0));
  }
  
  public final int getStingerCount() {
    return ((Integer)this.entityData.get(DATA_STINGER_COUNT_ID)).intValue();
  }
  
  public final void setStingerCount(int param_0) {
    this.entityData.set(DATA_STINGER_COUNT_ID, Integer.valueOf(param_0));
  }
  
  private int getCurrentSwingDuration() {
    if (MobEffectUtil.hasDigSpeed(this))
      return 6 - 1 + MobEffectUtil.getDigSpeedAmplification(this); 
    if (hasEffect(MobEffects.DIG_SLOWDOWN))
      return 6 + (1 + getEffect(MobEffects.DIG_SLOWDOWN).getAmplifier()) * 2; 
    return 6;
  }
  
  public void swing(InteractionHand param_0) {
    swing(param_0, false);
  }
  
  public void swing(InteractionHand param_0, boolean param_1) {
    if (!this.swinging || this.swingTime >= getCurrentSwingDuration() / 2 || this.swingTime < 0) {
      this.swingTime = -1;
      this.swinging = true;
      this.swingingArm = param_0;
      if (this.level instanceof ServerLevel) {
        ClientboundAnimatePacket var_0 = new ClientboundAnimatePacket(this, (param_0 == InteractionHand.MAIN_HAND) ? 0 : 3);
        ServerChunkCache var_1 = ((ServerLevel)this.level).getChunkSource();
        if (param_1) {
          var_1.broadcastAndSend(this, (Packet)var_0);
        } else {
          var_1.broadcast(this, (Packet)var_0);
        } 
      } 
    } 
  }
  
  public void handleEntityEvent(byte param_0) {
    DamageSource var_4;
    SoundEvent var_6;
    int var_7;
    SoundEvent var_5;
    int var_8;
    switch (param_0) {
      case 2:
      case 33:
      case 36:
      case 37:
      case 44:
      case 57:
        this.animationSpeed = 1.5F;
        this.invulnerableTime = 20;
        this.hurtDuration = 10;
        this.hurtTime = this.hurtDuration;
        this.hurtDir = 0.0F;
        if (param_0 == 33)
          playSound(SoundEvents.THORNS_HIT, getSoundVolume(), (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.0F); 
        if (param_0 == 37) {
          DamageSource var_0 = DamageSource.ON_FIRE;
        } else if (param_0 == 36) {
          DamageSource var_1 = DamageSource.DROWN;
        } else if (param_0 == 44) {
          DamageSource var_2 = DamageSource.SWEET_BERRY_BUSH;
        } else if (param_0 == 57) {
          DamageSource var_3 = DamageSource.FREEZE;
        } else {
          var_4 = DamageSource.GENERIC;
        } 
        var_5 = getHurtSound(var_4);
        if (var_5 != null)
          playSound(var_5, getSoundVolume(), (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.0F); 
        hurt(DamageSource.GENERIC, 0.0F);
        this.lastDamageSource = var_4;
        this.lastDamageStamp = this.level.getGameTime();
        return;
      case 3:
        var_6 = getDeathSound();
        if (var_6 != null)
          playSound(var_6, getSoundVolume(), (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.0F); 
        if (!(this instanceof Player)) {
          setHealth(0.0F);
          die(DamageSource.GENERIC);
        } 
        return;
      case 30:
        playSound(SoundEvents.SHIELD_BREAK, 0.8F, 0.8F + this.level.random.nextFloat() * 0.4F);
        return;
      case 29:
        playSound(SoundEvents.SHIELD_BLOCK, 1.0F, 0.8F + this.level.random.nextFloat() * 0.4F);
        return;
      case 46:
        var_7 = 128;
        for (var_8 = 0; var_8 < 128; var_8++) {
          double var_9 = var_8 / 127.0D;
          float var_10 = (this.random.nextFloat() - 0.5F) * 0.2F;
          float var_11 = (this.random.nextFloat() - 0.5F) * 0.2F;
          float var_12 = (this.random.nextFloat() - 0.5F) * 0.2F;
          double var_13 = Mth.lerp(var_9, this.xo, getX()) + (this.random.nextDouble() - 0.5D) * getBbWidth() * 2.0D;
          double var_14 = Mth.lerp(var_9, this.yo, getY()) + this.random.nextDouble() * getBbHeight();
          double var_15 = Mth.lerp(var_9, this.zo, getZ()) + (this.random.nextDouble() - 0.5D) * getBbWidth() * 2.0D;
          this.level.addParticle((ParticleOptions)ParticleTypes.PORTAL, var_13, var_14, var_15, var_10, var_11, var_12);
        } 
        return;
      case 47:
        breakItem(getItemBySlot(EquipmentSlot.MAINHAND));
        return;
      case 48:
        breakItem(getItemBySlot(EquipmentSlot.OFFHAND));
        return;
      case 49:
        breakItem(getItemBySlot(EquipmentSlot.HEAD));
        return;
      case 50:
        breakItem(getItemBySlot(EquipmentSlot.CHEST));
        return;
      case 51:
        breakItem(getItemBySlot(EquipmentSlot.LEGS));
        return;
      case 52:
        breakItem(getItemBySlot(EquipmentSlot.FEET));
        return;
      case 54:
        HoneyBlock.showJumpParticles(this);
        return;
      case 55:
        swapHandItems();
        return;
      case 60:
        makePoofParticles();
        return;
    } 
    super.handleEntityEvent(param_0);
  }
  
  private void makePoofParticles() {
    for (int var_0 = 0; var_0 < 20; var_0++) {
      double var_1 = this.random.nextGaussian() * 0.02D;
      double var_2 = this.random.nextGaussian() * 0.02D;
      double var_3 = this.random.nextGaussian() * 0.02D;
      this.level.addParticle((ParticleOptions)ParticleTypes.POOF, getRandomX(1.0D), getRandomY(), getRandomZ(1.0D), var_1, var_2, var_3);
    } 
  }
  
  private void swapHandItems() {
    ItemStack var_0 = getItemBySlot(EquipmentSlot.OFFHAND);
    setItemSlot(EquipmentSlot.OFFHAND, getItemBySlot(EquipmentSlot.MAINHAND));
    setItemSlot(EquipmentSlot.MAINHAND, var_0);
  }
  
  protected void outOfWorld() {
    hurt(DamageSource.OUT_OF_WORLD, 4.0F);
  }
  
  protected void updateSwingTime() {
    int var_0 = getCurrentSwingDuration();
    if (this.swinging) {
      this.swingTime++;
      if (this.swingTime >= var_0) {
        this.swingTime = 0;
        this.swinging = false;
      } 
    } else {
      this.swingTime = 0;
    } 
    this.attackAnim = this.swingTime / var_0;
  }
  
  @Nullable
  public AttributeInstance getAttribute(Attribute param_0) {
    return getAttributes().getInstance(param_0);
  }
  
  public double getAttributeValue(Attribute param_0) {
    return getAttributes().getValue(param_0);
  }
  
  public double getAttributeBaseValue(Attribute param_0) {
    return getAttributes().getBaseValue(param_0);
  }
  
  public AttributeMap getAttributes() {
    return this.attributes;
  }
  
  public MobType getMobType() {
    return MobType.UNDEFINED;
  }
  
  public ItemStack getMainHandItem() {
    return getItemBySlot(EquipmentSlot.MAINHAND);
  }
  
  public ItemStack getOffhandItem() {
    return getItemBySlot(EquipmentSlot.OFFHAND);
  }
  
  public boolean isHolding(Item param_0) {
    return isHolding(param_1 -> param_1.is(param_0));
  }
  
  public boolean isHolding(Predicate<ItemStack> param_0) {
    return (param_0.test(getMainHandItem()) || param_0.test(getOffhandItem()));
  }
  
  public ItemStack getItemInHand(InteractionHand param_0) {
    if (param_0 == InteractionHand.MAIN_HAND)
      return getItemBySlot(EquipmentSlot.MAINHAND); 
    if (param_0 == InteractionHand.OFF_HAND)
      return getItemBySlot(EquipmentSlot.OFFHAND); 
    throw new IllegalArgumentException("Invalid hand " + param_0);
  }
  
  public void setItemInHand(InteractionHand param_0, ItemStack param_1) {
    if (param_0 == InteractionHand.MAIN_HAND) {
      setItemSlot(EquipmentSlot.MAINHAND, param_1);
    } else if (param_0 == InteractionHand.OFF_HAND) {
      setItemSlot(EquipmentSlot.OFFHAND, param_1);
    } else {
      throw new IllegalArgumentException("Invalid hand " + param_0);
    } 
  }
  
  public boolean hasItemInSlot(EquipmentSlot param_0) {
    return !getItemBySlot(param_0).isEmpty();
  }
  
  protected void verifyEquippedItem(ItemStack param_0) {
    CompoundTag var_0 = param_0.getTag();
    if (var_0 != null)
      param_0.getItem().verifyTagAfterLoad(var_0); 
  }
  
  public float getArmorCoverPercentage() {
    Iterable<ItemStack> var_0 = getArmorSlots();
    int var_1 = 0;
    int var_2 = 0;
    for (ItemStack var_3 : var_0) {
      if (!var_3.isEmpty())
        var_2++; 
      var_1++;
    } 
    return (var_1 > 0) ? (var_2 / var_1) : 0.0F;
  }
  
  public void setSprinting(boolean param_0) {
    super.setSprinting(param_0);
    AttributeInstance var_0 = getAttribute(Attributes.MOVEMENT_SPEED);
    if (var_0.getModifier(SPEED_MODIFIER_SPRINTING_UUID) != null)
      var_0.removeModifier(SPEED_MODIFIER_SPRINTING); 
    if (param_0)
      var_0.addTransientModifier(SPEED_MODIFIER_SPRINTING); 
  }
  
  protected float getSoundVolume() {
    return 1.0F;
  }
  
  public float getVoicePitch() {
    if (isBaby())
      return (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.5F; 
    return (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.0F;
  }
  
  protected boolean isImmobile() {
    return isDeadOrDying();
  }
  
  public void push(Entity param_0) {
    if (!isSleeping())
      super.push(param_0); 
  }
  
  private void dismountVehicle(Entity param_0) {
    Vec3 var_3;
    if (isRemoved()) {
      Vec3 var_0 = position();
    } else if (param_0.isRemoved() || this.level.getBlockState(param_0.blockPosition()).is((Tag)BlockTags.PORTALS)) {
      double var_1 = Math.max(getY(), param_0.getY());
      Vec3 var_2 = new Vec3(getX(), var_1, getZ());
    } else {
      var_3 = param_0.getDismountLocationForPassenger(this);
    } 
    dismountTo(var_3.x, var_3.y, var_3.z);
  }
  
  public boolean shouldShowName() {
    return isCustomNameVisible();
  }
  
  protected float getJumpPower() {
    return 0.42F * getBlockJumpFactor();
  }
  
  public double getJumpBoostPower() {
    return hasEffect(MobEffects.JUMP) ? (0.1F * (getEffect(MobEffects.JUMP).getAmplifier() + 1)) : 0.0D;
  }
  
  protected void jumpFromGround() {
    double var_0 = getJumpPower() + getJumpBoostPower();
    Vec3 var_1 = getDeltaMovement();
    setDeltaMovement(var_1.x, var_0, var_1.z);
    if (isSprinting()) {
      float var_2 = getYRot() * 0.017453292F;
      setDeltaMovement(getDeltaMovement().add((
            -Mth.sin(var_2) * 0.2F), 0.0D, (
            
            Mth.cos(var_2) * 0.2F)));
    } 
    this.hasImpulse = true;
  }
  
  protected void goDownInWater() {
    setDeltaMovement(getDeltaMovement().add(0.0D, -0.03999999910593033D, 0.0D));
  }
  
  protected void jumpInLiquid(Tag<Fluid> param_0) {
    setDeltaMovement(getDeltaMovement().add(0.0D, 0.03999999910593033D, 0.0D));
  }
  
  protected float getWaterSlowDown() {
    return 0.8F;
  }
  
  public boolean canStandOnFluid(Fluid param_0) {
    return false;
  }
  
  public void travel(Vec3 param_0) {
    if (isEffectiveAi() || isControlledByLocalInstance()) {
      double var_0 = 0.08D;
      boolean var_1 = ((getDeltaMovement()).y <= 0.0D);
      if (var_1 && hasEffect(MobEffects.SLOW_FALLING)) {
        var_0 = 0.01D;
        this.fallDistance = 0.0F;
      } 
      FluidState var_2 = this.level.getFluidState(blockPosition());
      if (isInWater() && isAffectedByFluids() && !canStandOnFluid(var_2.getType())) {
        double var_3 = getY();
        float var_4 = isSprinting() ? 0.9F : getWaterSlowDown();
        float var_5 = 0.02F;
        float var_6 = EnchantmentHelper.getDepthStrider(this);
        if (var_6 > 3.0F)
          var_6 = 3.0F; 
        if (!this.onGround)
          var_6 *= 0.5F; 
        if (var_6 > 0.0F) {
          var_4 += (0.54600006F - var_4) * var_6 / 3.0F;
          var_5 += (getSpeed() - var_5) * var_6 / 3.0F;
        } 
        if (hasEffect(MobEffects.DOLPHINS_GRACE))
          var_4 = 0.96F; 
        moveRelative(var_5, param_0);
        move(MoverType.SELF, getDeltaMovement());
        Vec3 var_7 = getDeltaMovement();
        if (this.horizontalCollision && onClimbable())
          var_7 = new Vec3(var_7.x, 0.2D, var_7.z); 
        setDeltaMovement(var_7.multiply(var_4, 0.800000011920929D, var_4));
        Vec3 var_8 = getFluidFallingAdjustedMovement(var_0, var_1, getDeltaMovement());
        setDeltaMovement(var_8);
        if (this.horizontalCollision && isFree(var_8.x, var_8.y + 0.6000000238418579D - getY() + var_3, var_8.z))
          setDeltaMovement(var_8.x, 0.30000001192092896D, var_8.z); 
      } else if (isInLava() && isAffectedByFluids() && !canStandOnFluid(var_2.getType())) {
        double var_9 = getY();
        moveRelative(0.02F, param_0);
        move(MoverType.SELF, getDeltaMovement());
        if (getFluidHeight((Tag<Fluid>)FluidTags.LAVA) <= getFluidJumpThreshold()) {
          setDeltaMovement(getDeltaMovement().multiply(0.5D, 0.800000011920929D, 0.5D));
          Vec3 var_10 = getFluidFallingAdjustedMovement(var_0, var_1, getDeltaMovement());
          setDeltaMovement(var_10);
        } else {
          setDeltaMovement(getDeltaMovement().scale(0.5D));
        } 
        if (!isNoGravity())
          setDeltaMovement(getDeltaMovement().add(0.0D, -var_0 / 4.0D, 0.0D)); 
        Vec3 var_11 = getDeltaMovement();
        if (this.horizontalCollision && isFree(var_11.x, var_11.y + 0.6000000238418579D - getY() + var_9, var_11.z))
          setDeltaMovement(var_11.x, 0.30000001192092896D, var_11.z); 
      } else if (isFallFlying()) {
        Vec3 var_12 = getDeltaMovement();
        if (var_12.y > -0.5D)
          this.fallDistance = 1.0F; 
        Vec3 var_13 = getLookAngle();
        float var_14 = getXRot() * 0.017453292F;
        double var_15 = Math.sqrt(var_13.x * var_13.x + var_13.z * var_13.z);
        double var_16 = var_12.horizontalDistance();
        double var_17 = var_13.length();
        float var_18 = Mth.cos(var_14);
        var_18 = (float)(var_18 * var_18 * Math.min(1.0D, var_17 / 0.4D));
        var_12 = getDeltaMovement().add(0.0D, var_0 * (-1.0D + var_18 * 0.75D), 0.0D);
        if (var_12.y < 0.0D && var_15 > 0.0D) {
          double var_19 = var_12.y * -0.1D * var_18;
          var_12 = var_12.add(var_13.x * var_19 / var_15, var_19, var_13.z * var_19 / var_15);
        } 
        if (var_14 < 0.0F && var_15 > 0.0D) {
          double var_20 = var_16 * -Mth.sin(var_14) * 0.04D;
          var_12 = var_12.add(-var_13.x * var_20 / var_15, var_20 * 3.2D, -var_13.z * var_20 / var_15);
        } 
        if (var_15 > 0.0D)
          var_12 = var_12.add((var_13.x / var_15 * var_16 - var_12.x) * 0.1D, 0.0D, (var_13.z / var_15 * var_16 - var_12.z) * 0.1D); 
        setDeltaMovement(var_12.multiply(0.9900000095367432D, 0.9800000190734863D, 0.9900000095367432D));
        move(MoverType.SELF, getDeltaMovement());
        if (this.horizontalCollision && !this.level.isClientSide) {
          double var_21 = getDeltaMovement().horizontalDistance();
          double var_22 = var_16 - var_21;
          float var_23 = (float)(var_22 * 10.0D - 3.0D);
          if (var_23 > 0.0F) {
            playSound(getFallDamageSound((int)var_23), 1.0F, 1.0F);
            hurt(DamageSource.FLY_INTO_WALL, var_23);
          } 
        } 
        if (this.onGround && !this.level.isClientSide)
          setSharedFlag(7, false); 
      } else {
        BlockPos var_24 = getBlockPosBelowThatAffectsMyMovement();
        float var_25 = this.level.getBlockState(var_24).getBlock().getFriction();
        float var_26 = this.onGround ? (var_25 * 0.91F) : 0.91F;
        Vec3 var_27 = handleRelativeFrictionAndCalculateMovement(param_0, var_25);
        double var_28 = var_27.y;
        if (hasEffect(MobEffects.LEVITATION)) {
          var_28 += (0.05D * (getEffect(MobEffects.LEVITATION).getAmplifier() + 1) - var_27.y) * 0.2D;
          this.fallDistance = 0.0F;
        } else if (!this.level.isClientSide || this.level.hasChunkAt(var_24)) {
          if (!isNoGravity())
            var_28 -= var_0; 
        } else if (getY() > this.level.getMinBuildHeight()) {
          var_28 = -0.1D;
        } else {
          var_28 = 0.0D;
        } 
        if (shouldDiscardFriction()) {
          setDeltaMovement(var_27.x, var_28, var_27.z);
        } else {
          setDeltaMovement(var_27.x * var_26, var_28 * 0.9800000190734863D, var_27.z * var_26);
        } 
      } 
    } 
    calculateEntityAnimation(this, this instanceof net.minecraft.world.entity.animal.FlyingAnimal);
  }
  
  public void calculateEntityAnimation(LivingEntity param_0, boolean param_1) {
    param_0.animationSpeedOld = param_0.animationSpeed;
    double var_0 = param_0.getX() - param_0.xo;
    double var_1 = param_1 ? (param_0.getY() - param_0.yo) : 0.0D;
    double var_2 = param_0.getZ() - param_0.zo;
    float var_3 = (float)Math.sqrt(var_0 * var_0 + var_1 * var_1 + var_2 * var_2) * 4.0F;
    if (var_3 > 1.0F)
      var_3 = 1.0F; 
    param_0.animationSpeed += (var_3 - param_0.animationSpeed) * 0.4F;
    param_0.animationPosition += param_0.animationSpeed;
  }
  
  public Vec3 handleRelativeFrictionAndCalculateMovement(Vec3 param_0, float param_1) {
    moveRelative(getFrictionInfluencedSpeed(param_1), param_0);
    setDeltaMovement(handleOnClimbable(getDeltaMovement()));
    move(MoverType.SELF, getDeltaMovement());
    Vec3 var_0 = getDeltaMovement();
    if ((this.horizontalCollision || this.jumping) && (onClimbable() || (getFeetBlockState().is(Blocks.POWDER_SNOW) && PowderSnowBlock.canEntityWalkOnPowderSnow(this))))
      var_0 = new Vec3(var_0.x, 0.2D, var_0.z); 
    return var_0;
  }
  
  public Vec3 getFluidFallingAdjustedMovement(double param_0, boolean param_1, Vec3 param_2) {
    if (!isNoGravity() && !isSprinting()) {
      double var_1;
      if (param_1 && Math.abs(param_2.y - 0.005D) >= 0.003D && Math.abs(param_2.y - param_0 / 16.0D) < 0.003D) {
        double var_0 = -0.003D;
      } else {
        var_1 = param_2.y - param_0 / 16.0D;
      } 
      return new Vec3(param_2.x, var_1, param_2.z);
    } 
    return param_2;
  }
  
  private Vec3 handleOnClimbable(Vec3 param_0) {
    if (onClimbable()) {
      this.fallDistance = 0.0F;
      float var_0 = 0.15F;
      double var_1 = Mth.clamp(param_0.x, -0.15000000596046448D, 0.15000000596046448D);
      double var_2 = Mth.clamp(param_0.z, -0.15000000596046448D, 0.15000000596046448D);
      double var_3 = Math.max(param_0.y, -0.15000000596046448D);
      if (var_3 < 0.0D && !getFeetBlockState().is(Blocks.SCAFFOLDING) && isSuppressingSlidingDownLadder() && this instanceof Player)
        var_3 = 0.0D; 
      param_0 = new Vec3(var_1, var_3, var_2);
    } 
    return param_0;
  }
  
  private float getFrictionInfluencedSpeed(float param_0) {
    if (this.onGround)
      return getSpeed() * 0.21600002F / param_0 * param_0 * param_0; 
    return this.flyingSpeed;
  }
  
  public float getSpeed() {
    return this.speed;
  }
  
  public void setSpeed(float param_0) {
    this.speed = param_0;
  }
  
  public boolean doHurtTarget(Entity param_0) {
    setLastHurtMob(param_0);
    return false;
  }
  
  public void tick() {
    super.tick();
    updatingUsingItem();
    updateSwimAmount();
    if (!this.level.isClientSide) {
      int var_0 = getArrowCount();
      if (var_0 > 0) {
        if (this.removeArrowTime <= 0)
          this.removeArrowTime = 20 * (30 - var_0); 
        this.removeArrowTime--;
        if (this.removeArrowTime <= 0)
          setArrowCount(var_0 - 1); 
      } 
      int var_1 = getStingerCount();
      if (var_1 > 0) {
        if (this.removeStingerTime <= 0)
          this.removeStingerTime = 20 * (30 - var_1); 
        this.removeStingerTime--;
        if (this.removeStingerTime <= 0)
          setStingerCount(var_1 - 1); 
      } 
      detectEquipmentUpdates();
      if (this.tickCount % 20 == 0)
        getCombatTracker().recheckStatus(); 
      if (isSleeping() && !checkBedExists())
        stopSleeping(); 
    } 
    aiStep();
    double var_2 = getX() - this.xo;
    double var_3 = getZ() - this.zo;
    float var_4 = (float)(var_2 * var_2 + var_3 * var_3);
    float var_5 = this.yBodyRot;
    float var_6 = 0.0F;
    this.oRun = this.run;
    float var_7 = 0.0F;
    if (var_4 > 0.0025000002F) {
      var_7 = 1.0F;
      var_6 = (float)Math.sqrt(var_4) * 3.0F;
      float var_8 = (float)Mth.atan2(var_3, var_2) * 57.295776F - 90.0F;
      float var_9 = Mth.abs(Mth.wrapDegrees(getYRot()) - var_8);
      if (95.0F < var_9 && var_9 < 265.0F) {
        var_5 = var_8 - 180.0F;
      } else {
        var_5 = var_8;
      } 
    } 
    if (this.attackAnim > 0.0F)
      var_5 = getYRot(); 
    if (!this.onGround)
      var_7 = 0.0F; 
    this.run += (var_7 - this.run) * 0.3F;
    this.level.getProfiler().push("headTurn");
    var_6 = tickHeadTurn(var_5, var_6);
    this.level.getProfiler().pop();
    this.level.getProfiler().push("rangeChecks");
    while (getYRot() - this.yRotO < -180.0F)
      this.yRotO -= 360.0F; 
    while (getYRot() - this.yRotO >= 180.0F)
      this.yRotO += 360.0F; 
    while (this.yBodyRot - this.yBodyRotO < -180.0F)
      this.yBodyRotO -= 360.0F; 
    while (this.yBodyRot - this.yBodyRotO >= 180.0F)
      this.yBodyRotO += 360.0F; 
    while (getXRot() - this.xRotO < -180.0F)
      this.xRotO -= 360.0F; 
    while (getXRot() - this.xRotO >= 180.0F)
      this.xRotO += 360.0F; 
    while (this.yHeadRot - this.yHeadRotO < -180.0F)
      this.yHeadRotO -= 360.0F; 
    while (this.yHeadRot - this.yHeadRotO >= 180.0F)
      this.yHeadRotO += 360.0F; 
    this.level.getProfiler().pop();
    this.animStep += var_6;
    if (isFallFlying()) {
      this.fallFlyTicks++;
    } else {
      this.fallFlyTicks = 0;
    } 
    if (isSleeping())
      setXRot(0.0F); 
  }
  
  private void detectEquipmentUpdates() {
    Map<EquipmentSlot, ItemStack> var_0 = collectEquipmentChanges();
    if (var_0 != null) {
      handleHandSwap(var_0);
      if (!var_0.isEmpty())
        handleEquipmentChanges(var_0); 
    } 
  }
  
  @Nullable
  private Map<EquipmentSlot, ItemStack> collectEquipmentChanges() {
    Map<EquipmentSlot, ItemStack> var_0 = null;
    EquipmentSlot[] arrayOfEquipmentSlot;
    int i;
    byte b;
    for (arrayOfEquipmentSlot = EquipmentSlot.values(), i = arrayOfEquipmentSlot.length, b = 0; b < i; ) {
      ItemStack var_2, var_3;
      EquipmentSlot var_1 = arrayOfEquipmentSlot[b];
      switch (var_1.getType()) {
        case MAINHAND:
          var_2 = getLastHandItem(var_1);
          break;
        case OFFHAND:
          var_3 = getLastArmorItem(var_1);
          break;
        default:
          b++;
          continue;
      } 
      ItemStack var_5 = getItemBySlot(var_1);
      if (!ItemStack.matches(var_5, var_3)) {
        if (var_0 == null)
          var_0 = Maps.newEnumMap(EquipmentSlot.class); 
        var_0.put(var_1, var_5);
        if (!var_3.isEmpty())
          getAttributes().removeAttributeModifiers(var_3.getAttributeModifiers(var_1)); 
        if (!var_5.isEmpty())
          getAttributes().addTransientAttributeModifiers(var_5.getAttributeModifiers(var_1)); 
      } 
    } 
    return var_0;
  }
  
  private void handleHandSwap(Map<EquipmentSlot, ItemStack> param_0) {
    ItemStack var_0 = param_0.get(EquipmentSlot.MAINHAND);
    ItemStack var_1 = param_0.get(EquipmentSlot.OFFHAND);
    if (var_0 != null && var_1 != null && 
      ItemStack.matches(var_0, getLastHandItem(EquipmentSlot.OFFHAND)) && 
      ItemStack.matches(var_1, getLastHandItem(EquipmentSlot.MAINHAND))) {
      ((ServerLevel)this.level).getChunkSource().broadcast(this, (Packet)new ClientboundEntityEventPacket(this, (byte)55));
      param_0.remove(EquipmentSlot.MAINHAND);
      param_0.remove(EquipmentSlot.OFFHAND);
      setLastHandItem(EquipmentSlot.MAINHAND, var_0.copy());
      setLastHandItem(EquipmentSlot.OFFHAND, var_1.copy());
    } 
  }
  
  private void handleEquipmentChanges(Map<EquipmentSlot, ItemStack> param_0) {
    List<Pair<EquipmentSlot, ItemStack>> var_0 = Lists.newArrayListWithCapacity(param_0.size());
    param_0.forEach((param_1, param_2) -> {
          ItemStack var_0 = param_2.copy();
          param_0.add(Pair.of(param_1, var_0));
          switch (param_1.getType()) {
            case MAINHAND:
              setLastHandItem(param_1, var_0);
              break;
            case OFFHAND:
              setLastArmorItem(param_1, var_0);
              break;
          } 
        });
    ((ServerLevel)this.level).getChunkSource().broadcast(this, (Packet)new ClientboundSetEquipmentPacket(getId(), var_0));
  }
  
  private ItemStack getLastArmorItem(EquipmentSlot param_0) {
    return (ItemStack)this.lastArmorItemStacks.get(param_0.getIndex());
  }
  
  private void setLastArmorItem(EquipmentSlot param_0, ItemStack param_1) {
    this.lastArmorItemStacks.set(param_0.getIndex(), param_1);
  }
  
  private ItemStack getLastHandItem(EquipmentSlot param_0) {
    return (ItemStack)this.lastHandItemStacks.get(param_0.getIndex());
  }
  
  private void setLastHandItem(EquipmentSlot param_0, ItemStack param_1) {
    this.lastHandItemStacks.set(param_0.getIndex(), param_1);
  }
  
  protected float tickHeadTurn(float param_0, float param_1) {
    float var_0 = Mth.wrapDegrees(param_0 - this.yBodyRot);
    this.yBodyRot += var_0 * 0.3F;
    float var_1 = Mth.wrapDegrees(getYRot() - this.yBodyRot);
    boolean var_2 = (var_1 < -90.0F || var_1 >= 90.0F);
    if (var_1 < -75.0F)
      var_1 = -75.0F; 
    if (var_1 >= 75.0F)
      var_1 = 75.0F; 
    this.yBodyRot = getYRot() - var_1;
    if (var_1 * var_1 > 2500.0F)
      this.yBodyRot += var_1 * 0.2F; 
    if (var_2)
      param_1 *= -1.0F; 
    return param_1;
  }
  
  public void aiStep() {
    if (this.noJumpDelay > 0)
      this.noJumpDelay--; 
    if (isControlledByLocalInstance()) {
      this.lerpSteps = 0;
      setPacketCoordinates(getX(), getY(), getZ());
    } 
    if (this.lerpSteps > 0) {
      double var_0 = getX() + (this.lerpX - getX()) / this.lerpSteps;
      double var_1 = getY() + (this.lerpY - getY()) / this.lerpSteps;
      double var_2 = getZ() + (this.lerpZ - getZ()) / this.lerpSteps;
      double var_3 = Mth.wrapDegrees(this.lerpYRot - getYRot());
      setYRot(getYRot() + (float)var_3 / this.lerpSteps);
      setXRot(getXRot() + (float)(this.lerpXRot - getXRot()) / this.lerpSteps);
      this.lerpSteps--;
      setPos(var_0, var_1, var_2);
      setRot(getYRot(), getXRot());
    } else if (!isEffectiveAi()) {
      setDeltaMovement(getDeltaMovement().scale(0.98D));
    } 
    if (this.lerpHeadSteps > 0) {
      this.yHeadRot = (float)(this.yHeadRot + Mth.wrapDegrees(this.lyHeadRot - this.yHeadRot) / this.lerpHeadSteps);
      this.lerpHeadSteps--;
    } 
    Vec3 var_4 = getDeltaMovement();
    double var_5 = var_4.x;
    double var_6 = var_4.y;
    double var_7 = var_4.z;
    if (Math.abs(var_4.x) < 0.003D)
      var_5 = 0.0D; 
    if (Math.abs(var_4.y) < 0.003D)
      var_6 = 0.0D; 
    if (Math.abs(var_4.z) < 0.003D)
      var_7 = 0.0D; 
    setDeltaMovement(var_5, var_6, var_7);
    this.level.getProfiler().push("ai");
    if (isImmobile()) {
      this.jumping = false;
      this.xxa = 0.0F;
      this.zza = 0.0F;
    } else if (isEffectiveAi()) {
      this.level.getProfiler().push("newAi");
      serverAiStep();
      this.level.getProfiler().pop();
    } 
    this.level.getProfiler().pop();
    this.level.getProfiler().push("jump");
    if (this.jumping && isAffectedByFluids()) {
      double var_9;
      if (isInLava()) {
        double var_8 = getFluidHeight((Tag<Fluid>)FluidTags.LAVA);
      } else {
        var_9 = getFluidHeight((Tag<Fluid>)FluidTags.WATER);
      } 
      boolean var_10 = (isInWater() && var_9 > 0.0D);
      double var_11 = getFluidJumpThreshold();
      if (var_10 && (!this.onGround || var_9 > var_11)) {
        jumpInLiquid((Tag<Fluid>)FluidTags.WATER);
      } else if (isInLava() && (!this.onGround || var_9 > var_11)) {
        jumpInLiquid((Tag<Fluid>)FluidTags.LAVA);
      } else if ((this.onGround || (var_10 && var_9 <= var_11)) && 
        this.noJumpDelay == 0) {
        jumpFromGround();
        this.noJumpDelay = 10;
      } 
    } else {
      this.noJumpDelay = 0;
    } 
    this.level.getProfiler().pop();
    this.level.getProfiler().push("travel");
    this.xxa *= 0.98F;
    this.zza *= 0.98F;
    updateFallFlying();
    AABB var_12 = getBoundingBox();
    travel(new Vec3(this.xxa, this.yya, this.zza));
    this.level.getProfiler().pop();
    this.level.getProfiler().push("freezing");
    boolean var_13 = getType().is((Tag<EntityType<?>>)EntityTypeTags.FREEZE_HURTS_EXTRA_TYPES);
    if (!this.level.isClientSide && !isDeadOrDying()) {
      int var_14 = getTicksFrozen();
      if (this.isInPowderSnow && canFreeze()) {
        setTicksFrozen(Math.min(getTicksRequiredToFreeze(), var_14 + 1));
      } else {
        setTicksFrozen(Math.max(0, var_14 - 2));
      } 
    } 
    removeFrost();
    tryAddFrost();
    if (!this.level.isClientSide && this.tickCount % 40 == 0 && isFullyFrozen() && canFreeze()) {
      int var_15 = var_13 ? 5 : 1;
      hurt(DamageSource.FREEZE, var_15);
    } 
    this.level.getProfiler().pop();
    this.level.getProfiler().push("push");
    if (this.autoSpinAttackTicks > 0) {
      this.autoSpinAttackTicks--;
      checkAutoSpinAttack(var_12, getBoundingBox());
    } 
    pushEntities();
    this.level.getProfiler().pop();
    if (!this.level.isClientSide && isSensitiveToWater() && isInWaterRainOrBubble())
      hurt(DamageSource.DROWN, 1.0F); 
  }
  
  public boolean isSensitiveToWater() {
    return false;
  }
  
  private void updateFallFlying() {
    boolean var_0 = getSharedFlag(7);
    if (var_0 && !this.onGround && !isPassenger() && !hasEffect(MobEffects.LEVITATION)) {
      ItemStack var_1 = getItemBySlot(EquipmentSlot.CHEST);
      if (var_1.is(Items.ELYTRA) && ElytraItem.isFlyEnabled(var_1)) {
        var_0 = true;
        int var_2 = this.fallFlyTicks + 1;
        if (!this.level.isClientSide && var_2 % 10 == 0) {
          int var_3 = var_2 / 10;
          if (var_3 % 2 == 0)
            var_1.hurtAndBreak(1, this, param_0 -> param_0.broadcastBreakEvent(EquipmentSlot.CHEST)); 
          gameEvent(GameEvent.ELYTRA_FREE_FALL);
        } 
      } else {
        var_0 = false;
      } 
    } else {
      var_0 = false;
    } 
    if (!this.level.isClientSide)
      setSharedFlag(7, var_0); 
  }
  
  protected void serverAiStep() {}
  
  protected void pushEntities() {
    List<Entity> var_0 = this.level.getEntities(this, getBoundingBox(), EntitySelector.pushableBy(this));
    if (!var_0.isEmpty()) {
      int var_1 = this.level.getGameRules().getInt(GameRules.RULE_MAX_ENTITY_CRAMMING);
      if (var_1 > 0 && var_0.size() > var_1 - 1 && this.random.nextInt(4) == 0) {
        int var_2 = 0;
        for (int var_3 = 0; var_3 < var_0.size(); var_3++) {
          if (!((Entity)var_0.get(var_3)).isPassenger())
            var_2++; 
        } 
        if (var_2 > var_1 - 1)
          hurt(DamageSource.CRAMMING, 6.0F); 
      } 
      for (int var_4 = 0; var_4 < var_0.size(); var_4++) {
        Entity var_5 = var_0.get(var_4);
        doPush(var_5);
      } 
    } 
  }
  
  protected void checkAutoSpinAttack(AABB param_0, AABB param_1) {
    AABB var_0 = param_0.minmax(param_1);
    List<Entity> var_1 = this.level.getEntities(this, var_0);
    if (!var_1.isEmpty()) {
      for (int var_2 = 0; var_2 < var_1.size(); var_2++) {
        Entity var_3 = var_1.get(var_2);
        if (var_3 instanceof LivingEntity) {
          doAutoAttackOnTouch((LivingEntity)var_3);
          this.autoSpinAttackTicks = 0;
          setDeltaMovement(getDeltaMovement().scale(-0.2D));
          break;
        } 
      } 
    } else if (this.horizontalCollision) {
      this.autoSpinAttackTicks = 0;
    } 
    if (!this.level.isClientSide && this.autoSpinAttackTicks <= 0)
      setLivingEntityFlag(4, false); 
  }
  
  protected void doPush(Entity param_0) {
    param_0.push(this);
  }
  
  protected void doAutoAttackOnTouch(LivingEntity param_0) {}
  
  public void startAutoSpinAttack(int param_0) {
    this.autoSpinAttackTicks = param_0;
    if (!this.level.isClientSide)
      setLivingEntityFlag(4, true); 
  }
  
  public boolean isAutoSpinAttack() {
    return ((((Byte)this.entityData.get(DATA_LIVING_ENTITY_FLAGS)).byteValue() & 0x4) != 0);
  }
  
  public void stopRiding() {
    Entity var_0 = getVehicle();
    super.stopRiding();
    if (var_0 != null && var_0 != getVehicle() && !this.level.isClientSide)
      dismountVehicle(var_0); 
  }
  
  public void rideTick() {
    super.rideTick();
    this.oRun = this.run;
    this.run = 0.0F;
    this.fallDistance = 0.0F;
  }
  
  public void lerpTo(double param_0, double param_1, double param_2, float param_3, float param_4, int param_5, boolean param_6) {
    this.lerpX = param_0;
    this.lerpY = param_1;
    this.lerpZ = param_2;
    this.lerpYRot = param_3;
    this.lerpXRot = param_4;
    this.lerpSteps = param_5;
  }
  
  public void lerpHeadTo(float param_0, int param_1) {
    this.lyHeadRot = param_0;
    this.lerpHeadSteps = param_1;
  }
  
  public void setJumping(boolean param_0) {
    this.jumping = param_0;
  }
  
  public void onItemPickup(ItemEntity param_0) {
    Player var_0 = (param_0.getThrower() != null) ? this.level.getPlayerByUUID(param_0.getThrower()) : null;
    if (var_0 instanceof ServerPlayer)
      CriteriaTriggers.ITEM_PICKED_UP_BY_ENTITY.trigger((ServerPlayer)var_0, param_0.getItem(), this); 
  }
  
  public void take(Entity param_0, int param_1) {
    if (!param_0.isRemoved() && !this.level.isClientSide && (
      param_0 instanceof ItemEntity || param_0 instanceof AbstractArrow || param_0 instanceof ExperienceOrb))
      ((ServerLevel)this.level).getChunkSource().broadcast(param_0, (Packet)new ClientboundTakeItemEntityPacket(param_0.getId(), getId(), param_1)); 
  }
  
  public boolean hasLineOfSight(Entity param_0) {
    if (param_0.level != this.level)
      return false; 
    Vec3 var_0 = new Vec3(getX(), getEyeY(), getZ());
    Vec3 var_1 = new Vec3(param_0.getX(), param_0.getEyeY(), param_0.getZ());
    if (var_1.distanceTo(var_0) > 128.0D)
      return false; 
    return (this.level.clip(new ClipContext(var_0, var_1, ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, this)).getType() == HitResult.Type.MISS);
  }
  
  public float getViewYRot(float param_0) {
    if (param_0 == 1.0F)
      return this.yHeadRot; 
    return Mth.lerp(param_0, this.yHeadRotO, this.yHeadRot);
  }
  
  public float getAttackAnim(float param_0) {
    float var_0 = this.attackAnim - this.oAttackAnim;
    if (var_0 < 0.0F)
      var_0++; 
    return this.oAttackAnim + var_0 * param_0;
  }
  
  public boolean isEffectiveAi() {
    return !this.level.isClientSide;
  }
  
  public boolean isPickable() {
    return !isRemoved();
  }
  
  public boolean isPushable() {
    return (isAlive() && !isSpectator() && !onClimbable());
  }
  
  protected void markHurt() {
    this.hurtMarked = (this.random.nextDouble() >= getAttributeValue(Attributes.KNOCKBACK_RESISTANCE));
  }
  
  public float getYHeadRot() {
    return this.yHeadRot;
  }
  
  public void setYHeadRot(float param_0) {
    this.yHeadRot = param_0;
  }
  
  public void setYBodyRot(float param_0) {
    this.yBodyRot = param_0;
  }
  
  protected Vec3 getRelativePortalPosition(Direction.Axis param_0, BlockUtil.FoundRectangle param_1) {
    return resetForwardDirectionOfRelativePortalPosition(super.getRelativePortalPosition(param_0, param_1));
  }
  
  public static Vec3 resetForwardDirectionOfRelativePortalPosition(Vec3 param_0) {
    return new Vec3(param_0.x, param_0.y, 0.0D);
  }
  
  public float getAbsorptionAmount() {
    return this.absorptionAmount;
  }
  
  public void setAbsorptionAmount(float param_0) {
    if (param_0 < 0.0F)
      param_0 = 0.0F; 
    this.absorptionAmount = param_0;
  }
  
  public void onEnterCombat() {}
  
  public void onLeaveCombat() {}
  
  protected void updateEffectVisibility() {
    this.effectsDirty = true;
  }
  
  public boolean isUsingItem() {
    return ((((Byte)this.entityData.get(DATA_LIVING_ENTITY_FLAGS)).byteValue() & 0x1) > 0);
  }
  
  public InteractionHand getUsedItemHand() {
    return ((((Byte)this.entityData.get(DATA_LIVING_ENTITY_FLAGS)).byteValue() & 0x2) > 0) ? InteractionHand.OFF_HAND : InteractionHand.MAIN_HAND;
  }
  
  private void updatingUsingItem() {
    if (isUsingItem())
      if (ItemStack.isSameIgnoreDurability(getItemInHand(getUsedItemHand()), this.useItem)) {
        this.useItem = getItemInHand(getUsedItemHand());
        updateUsingItem(this.useItem);
      } else {
        stopUsingItem();
      }  
  }
  
  protected void updateUsingItem(ItemStack param_0) {
    param_0.onUseTick(this.level, this, getUseItemRemainingTicks());
    if (shouldTriggerItemUseEffects())
      triggerItemUseEffects(param_0, 5); 
    if (--this.useItemRemaining == 0 && !this.level.isClientSide && !param_0.useOnRelease())
      completeUsingItem(); 
  }
  
  private boolean shouldTriggerItemUseEffects() {
    int var_0 = getUseItemRemainingTicks();
    FoodProperties var_1 = this.useItem.getItem().getFoodProperties();
    boolean var_2 = (var_1 != null && var_1.isFastFood());
    int i = var_2 | ((var_0 <= this.useItem.getUseDuration() - 7) ? 1 : 0);
    return (i != 0 && var_0 % 4 == 0);
  }
  
  private void updateSwimAmount() {
    this.swimAmountO = this.swimAmount;
    if (isVisuallySwimming()) {
      this.swimAmount = Math.min(1.0F, this.swimAmount + 0.09F);
    } else {
      this.swimAmount = Math.max(0.0F, this.swimAmount - 0.09F);
    } 
  }
  
  protected void setLivingEntityFlag(int param_0, boolean param_1) {
    int var_0 = ((Byte)this.entityData.get(DATA_LIVING_ENTITY_FLAGS)).byteValue();
    if (param_1) {
      var_0 |= param_0;
    } else {
      var_0 &= param_0 ^ 0xFFFFFFFF;
    } 
    this.entityData.set(DATA_LIVING_ENTITY_FLAGS, Byte.valueOf((byte)var_0));
  }
  
  public void startUsingItem(InteractionHand param_0) {
    ItemStack var_0 = getItemInHand(param_0);
    if (var_0.isEmpty() || isUsingItem())
      return; 
    this.useItem = var_0;
    this.useItemRemaining = var_0.getUseDuration();
    if (!this.level.isClientSide) {
      setLivingEntityFlag(1, true);
      setLivingEntityFlag(2, (param_0 == InteractionHand.OFF_HAND));
    } 
  }
  
  public void onSyncedDataUpdated(EntityDataAccessor<?> param_0) {
    super.onSyncedDataUpdated(param_0);
    if (SLEEPING_POS_ID.equals(param_0)) {
      if (this.level.isClientSide)
        getSleepingPos().ifPresent(this::setPosToBed); 
    } else if (DATA_LIVING_ENTITY_FLAGS.equals(param_0) && this.level.isClientSide) {
      if (isUsingItem() && this.useItem.isEmpty()) {
        this.useItem = getItemInHand(getUsedItemHand());
        if (!this.useItem.isEmpty())
          this.useItemRemaining = this.useItem.getUseDuration(); 
      } else if (!isUsingItem() && !this.useItem.isEmpty()) {
        this.useItem = ItemStack.EMPTY;
        this.useItemRemaining = 0;
      } 
    } 
  }
  
  public void lookAt(EntityAnchorArgument.Anchor param_0, Vec3 param_1) {
    super.lookAt(param_0, param_1);
    this.yHeadRotO = this.yHeadRot;
    this.yBodyRot = this.yHeadRot;
    this.yBodyRotO = this.yBodyRot;
  }
  
  protected void triggerItemUseEffects(ItemStack param_0, int param_1) {
    if (param_0.isEmpty() || !isUsingItem())
      return; 
    if (param_0.getUseAnimation() == UseAnim.DRINK)
      playSound(getDrinkingSound(param_0), 0.5F, this.level.random.nextFloat() * 0.1F + 0.9F); 
    if (param_0.getUseAnimation() == UseAnim.EAT) {
      spawnItemParticles(param_0, param_1);
      playSound(getEatingSound(param_0), 0.5F + 0.5F * this.random.nextInt(2), (this.random.nextFloat() - this.random.nextFloat()) * 0.2F + 1.0F);
    } 
  }
  
  private void spawnItemParticles(ItemStack param_0, int param_1) {
    for (int var_0 = 0; var_0 < param_1; var_0++) {
      Vec3 var_1 = new Vec3((this.random.nextFloat() - 0.5D) * 0.1D, Math.random() * 0.1D + 0.1D, 0.0D);
      var_1 = var_1.xRot(-getXRot() * 0.017453292F);
      var_1 = var_1.yRot(-getYRot() * 0.017453292F);
      double var_2 = -this.random.nextFloat() * 0.6D - 0.3D;
      Vec3 var_3 = new Vec3((this.random.nextFloat() - 0.5D) * 0.3D, var_2, 0.6D);
      var_3 = var_3.xRot(-getXRot() * 0.017453292F);
      var_3 = var_3.yRot(-getYRot() * 0.017453292F);
      var_3 = var_3.add(getX(), getEyeY(), getZ());
      this.level.addParticle((ParticleOptions)new ItemParticleOption(ParticleTypes.ITEM, param_0), var_3.x, var_3.y, var_3.z, var_1.x, var_1.y + 0.05D, var_1.z);
    } 
  }
  
  protected void completeUsingItem() {
    InteractionHand var_0 = getUsedItemHand();
    if (!this.useItem.equals(getItemInHand(var_0))) {
      releaseUsingItem();
      return;
    } 
    if (!this.useItem.isEmpty() && isUsingItem()) {
      triggerItemUseEffects(this.useItem, 16);
      ItemStack var_1 = this.useItem.finishUsingItem(this.level, this);
      if (var_1 != this.useItem)
        setItemInHand(var_0, var_1); 
      stopUsingItem();
    } 
  }
  
  public ItemStack getUseItem() {
    return this.useItem;
  }
  
  public int getUseItemRemainingTicks() {
    return this.useItemRemaining;
  }
  
  public int getTicksUsingItem() {
    if (isUsingItem())
      return this.useItem.getUseDuration() - getUseItemRemainingTicks(); 
    return 0;
  }
  
  public void releaseUsingItem() {
    if (!this.useItem.isEmpty()) {
      this.useItem.releaseUsing(this.level, this, getUseItemRemainingTicks());
      if (this.useItem.useOnRelease())
        updatingUsingItem(); 
    } 
    stopUsingItem();
  }
  
  public void stopUsingItem() {
    if (!this.level.isClientSide)
      setLivingEntityFlag(1, false); 
    this.useItem = ItemStack.EMPTY;
    this.useItemRemaining = 0;
  }
  
  public boolean isBlocking() {
    if (!isUsingItem() || this.useItem.isEmpty())
      return false; 
    Item var_0 = this.useItem.getItem();
    if (var_0.getUseAnimation(this.useItem) != UseAnim.BLOCK)
      return false; 
    if (var_0.getUseDuration(this.useItem) - this.useItemRemaining < 5)
      return false; 
    return true;
  }
  
  public boolean isSuppressingSlidingDownLadder() {
    return isShiftKeyDown();
  }
  
  public boolean isFallFlying() {
    return getSharedFlag(7);
  }
  
  public boolean isVisuallySwimming() {
    return (super.isVisuallySwimming() || (!isFallFlying() && getPose() == Pose.FALL_FLYING));
  }
  
  public int getFallFlyingTicks() {
    return this.fallFlyTicks;
  }
  
  public boolean randomTeleport(double param_0, double param_1, double param_2, boolean param_3) {
    double var_0 = getX();
    double var_1 = getY();
    double var_2 = getZ();
    double var_3 = param_1;
    boolean var_4 = false;
    BlockPos var_5 = new BlockPos(param_0, var_3, param_2);
    Level var_6 = this.level;
    if (var_6.hasChunkAt(var_5)) {
      boolean var_7 = false;
      while (!var_7 && var_5.getY() > var_6.getMinBuildHeight()) {
        BlockPos var_8 = var_5.below();
        BlockState var_9 = var_6.getBlockState(var_8);
        if (var_9.getMaterial().blocksMotion()) {
          var_7 = true;
          continue;
        } 
        var_3--;
        var_5 = var_8;
      } 
      if (var_7) {
        teleportTo(param_0, var_3, param_2);
        if (var_6.noCollision(this) && !var_6.containsAnyLiquid(getBoundingBox()))
          var_4 = true; 
      } 
    } 
    if (!var_4) {
      teleportTo(var_0, var_1, var_2);
      return false;
    } 
    if (param_3)
      var_6.broadcastEntityEvent(this, (byte)46); 
    if (this instanceof PathfinderMob)
      ((PathfinderMob)this).getNavigation().stop(); 
    return true;
  }
  
  public boolean isAffectedByPotions() {
    return true;
  }
  
  public boolean attackable() {
    return true;
  }
  
  public void setRecordPlayingNearby(BlockPos param_0, boolean param_1) {}
  
  public boolean canTakeItem(ItemStack param_0) {
    return false;
  }
  
  public Packet<?> getAddEntityPacket() {
    return (Packet<?>)new ClientboundAddMobPacket(this);
  }
  
  public EntityDimensions getDimensions(Pose param_0) {
    return (param_0 == Pose.SLEEPING) ? SLEEPING_DIMENSIONS : super.getDimensions(param_0).scale(getScale());
  }
  
  public ImmutableList<Pose> getDismountPoses() {
    return ImmutableList.of(Pose.STANDING);
  }
  
  public AABB getLocalBoundsForPose(Pose param_0) {
    EntityDimensions var_0 = getDimensions(param_0);
    return new AABB((-var_0.width / 2.0F), 0.0D, (-var_0.width / 2.0F), (var_0.width / 2.0F), var_0.height, (var_0.width / 2.0F));
  }
  
  public Optional<BlockPos> getSleepingPos() {
    return (Optional<BlockPos>)this.entityData.get(SLEEPING_POS_ID);
  }
  
  public void setSleepingPos(BlockPos param_0) {
    this.entityData.set(SLEEPING_POS_ID, Optional.of(param_0));
  }
  
  public void clearSleepingPos() {
    this.entityData.set(SLEEPING_POS_ID, Optional.empty());
  }
  
  public boolean isSleeping() {
    return getSleepingPos().isPresent();
  }
  
  public void startSleeping(BlockPos param_0) {
    if (isPassenger())
      stopRiding(); 
    BlockState var_0 = this.level.getBlockState(param_0);
    if (var_0.getBlock() instanceof BedBlock)
      this.level.setBlock(param_0, (BlockState)var_0.setValue((Property)BedBlock.OCCUPIED, Boolean.valueOf(true)), 3); 
    setPose(Pose.SLEEPING);
    setPosToBed(param_0);
    setSleepingPos(param_0);
    setDeltaMovement(Vec3.ZERO);
    this.hasImpulse = true;
  }
  
  private void setPosToBed(BlockPos param_0) {
    setPos(param_0.getX() + 0.5D, param_0.getY() + 0.6875D, param_0.getZ() + 0.5D);
  }
  
  private boolean checkBedExists() {
    return ((Boolean)getSleepingPos().<Boolean>map(param_0 -> Boolean.valueOf(this.level.getBlockState(param_0).getBlock() instanceof BedBlock)).orElse(Boolean.valueOf(false))).booleanValue();
  }
  
  public void stopSleeping() {
    Objects.requireNonNull(this.level);
    getSleepingPos().filter(this.level::hasChunkAt).ifPresent(param_0 -> {
          BlockState var_0 = this.level.getBlockState(param_0);
          if (var_0.getBlock() instanceof BedBlock) {
            this.level.setBlock(param_0, (BlockState)var_0.setValue((Property)BedBlock.OCCUPIED, Boolean.valueOf(false)), 3);
            Vec3 var_1 = BedBlock.findStandUpPosition(getType(), (CollisionGetter)this.level, param_0, getYRot()).orElseGet(());
            Vec3 var_2 = Vec3.atBottomCenterOf((Vec3i)param_0).subtract(var_1).normalize();
            float var_3 = (float)Mth.wrapDegrees(Mth.atan2(var_2.z, var_2.x) * 57.2957763671875D - 90.0D);
            setPos(var_1.x, var_1.y, var_1.z);
            setYRot(var_3);
            setXRot(0.0F);
          } 
        });
    Vec3 var_0 = position();
    setPose(Pose.STANDING);
    setPos(var_0.x, var_0.y, var_0.z);
    clearSleepingPos();
  }
  
  @Nullable
  public Direction getBedOrientation() {
    BlockPos var_0 = getSleepingPos().orElse(null);
    return (var_0 != null) ? BedBlock.getBedOrientation((BlockGetter)this.level, var_0) : null;
  }
  
  public boolean isInWall() {
    return (!isSleeping() && super.isInWall());
  }
  
  protected final float getEyeHeight(Pose param_0, EntityDimensions param_1) {
    return (param_0 == Pose.SLEEPING) ? 0.2F : getStandingEyeHeight(param_0, param_1);
  }
  
  protected float getStandingEyeHeight(Pose param_0, EntityDimensions param_1) {
    return super.getEyeHeight(param_0, param_1);
  }
  
  public ItemStack getProjectile(ItemStack param_0) {
    return ItemStack.EMPTY;
  }
  
  public ItemStack eat(Level param_0, ItemStack param_1) {
    if (param_1.isEdible()) {
      param_0.gameEvent(this, GameEvent.EAT, eyeBlockPosition());
      param_0.playSound(null, getX(), getY(), getZ(), getEatingSound(param_1), SoundSource.NEUTRAL, 1.0F, 1.0F + (param_0.random.nextFloat() - param_0.random.nextFloat()) * 0.4F);
      addEatEffect(param_1, param_0, this);
      if (!(this instanceof Player) || !(((Player)this).getAbilities()).instabuild)
        param_1.shrink(1); 
      gameEvent(GameEvent.EAT);
    } 
    return param_1;
  }
  
  private void addEatEffect(ItemStack param_0, Level param_1, LivingEntity param_2) {
    Item var_0 = param_0.getItem();
    if (var_0.isEdible()) {
      List<Pair<MobEffectInstance, Float>> var_1 = var_0.getFoodProperties().getEffects();
      for (Pair<MobEffectInstance, Float> var_2 : var_1) {
        if (!param_1.isClientSide && var_2.getFirst() != null && param_1.random.nextFloat() < ((Float)var_2.getSecond()).floatValue())
          param_2.addEffect(new MobEffectInstance((MobEffectInstance)var_2.getFirst())); 
      } 
    } 
  }
  
  private static byte entityEventForEquipmentBreak(EquipmentSlot param_0) {
    switch (param_0) {
      case MAINHAND:
        return 47;
      case OFFHAND:
        return 48;
      case HEAD:
        return 49;
      case CHEST:
        return 50;
      case FEET:
        return 52;
      case LEGS:
        return 51;
    } 
    return 47;
  }
  
  public void broadcastBreakEvent(EquipmentSlot param_0) {
    this.level.broadcastEntityEvent(this, entityEventForEquipmentBreak(param_0));
  }
  
  public void broadcastBreakEvent(InteractionHand param_0) {
    broadcastBreakEvent((param_0 == InteractionHand.MAIN_HAND) ? EquipmentSlot.MAINHAND : EquipmentSlot.OFFHAND);
  }
  
  public AABB getBoundingBoxForCulling() {
    if (getItemBySlot(EquipmentSlot.HEAD).is(Items.DRAGON_HEAD)) {
      float var_0 = 0.5F;
      return getBoundingBox().inflate(0.5D, 0.5D, 0.5D);
    } 
    return super.getBoundingBoxForCulling();
  }
  
  public static EquipmentSlot getEquipmentSlotForItem(ItemStack param_0) {
    Item var_0 = param_0.getItem();
    if (param_0.is(Items.CARVED_PUMPKIN) || (var_0 instanceof BlockItem && ((BlockItem)var_0).getBlock() instanceof net.minecraft.world.level.block.AbstractSkullBlock))
      return EquipmentSlot.HEAD; 
    if (var_0 instanceof ArmorItem)
      return ((ArmorItem)var_0).getSlot(); 
    if (param_0.is(Items.ELYTRA))
      return EquipmentSlot.CHEST; 
    if (param_0.is(Items.SHIELD))
      return EquipmentSlot.OFFHAND; 
    return EquipmentSlot.MAINHAND;
  }
  
  private static SlotAccess createEquipmentSlotAccess(LivingEntity param_0, EquipmentSlot param_1) {
    if (param_1 == EquipmentSlot.HEAD || param_1 == EquipmentSlot.MAINHAND || param_1 == EquipmentSlot.OFFHAND)
      return SlotAccess.forEquipmentSlot(param_0, param_1); 
    return SlotAccess.forEquipmentSlot(param_0, param_1, param_1 -> (param_1.isEmpty() || Mob.getEquipmentSlotForItem(param_1) == param_0));
  }
  
  @Nullable
  private static EquipmentSlot getEquipmentSlot(int param_0) {
    if (param_0 == 100 + EquipmentSlot.HEAD.getIndex())
      return EquipmentSlot.HEAD; 
    if (param_0 == 100 + EquipmentSlot.CHEST.getIndex())
      return EquipmentSlot.CHEST; 
    if (param_0 == 100 + EquipmentSlot.LEGS.getIndex())
      return EquipmentSlot.LEGS; 
    if (param_0 == 100 + EquipmentSlot.FEET.getIndex())
      return EquipmentSlot.FEET; 
    if (param_0 == 98)
      return EquipmentSlot.MAINHAND; 
    if (param_0 == 99)
      return EquipmentSlot.OFFHAND; 
    return null;
  }
  
  public SlotAccess getSlot(int param_0) {
    EquipmentSlot var_0 = getEquipmentSlot(param_0);
    if (var_0 != null)
      return createEquipmentSlotAccess(this, var_0); 
    return super.getSlot(param_0);
  }
  
  public boolean canFreeze() {
    if (isSpectator())
      return false; 
    boolean var_0 = (!getItemBySlot(EquipmentSlot.HEAD).is((Tag)ItemTags.FREEZE_IMMUNE_WEARABLES) && !getItemBySlot(EquipmentSlot.CHEST).is((Tag)ItemTags.FREEZE_IMMUNE_WEARABLES) && !getItemBySlot(EquipmentSlot.LEGS).is((Tag)ItemTags.FREEZE_IMMUNE_WEARABLES) && !getItemBySlot(EquipmentSlot.FEET).is((Tag)ItemTags.FREEZE_IMMUNE_WEARABLES));
    return (var_0 && super.canFreeze());
  }
  
  public boolean isCurrentlyGlowing() {
    return ((!this.level.isClientSide() && hasEffect(MobEffects.GLOWING)) || super.isCurrentlyGlowing());
  }
  
  public void recreateFromPacket(ClientboundAddMobPacket param_0) {
    double var_0 = param_0.getX();
    double var_1 = param_0.getY();
    double var_2 = param_0.getZ();
    float var_3 = (param_0.getyRot() * 360) / 256.0F;
    float var_4 = (param_0.getxRot() * 360) / 256.0F;
    setPacketCoordinates(var_0, var_1, var_2);
    this.yBodyRot = (param_0.getyHeadRot() * 360) / 256.0F;
    this.yHeadRot = (param_0.getyHeadRot() * 360) / 256.0F;
    setId(param_0.getId());
    setUUID(param_0.getUUID());
    absMoveTo(var_0, var_1, var_2, var_3, var_4);
    setDeltaMovement((param_0
        .getXd() / 8000.0F), (param_0
        .getYd() / 8000.0F), (param_0
        .getZd() / 8000.0F));
  }
  
  public abstract Iterable<ItemStack> getArmorSlots();
  
  public abstract ItemStack getItemBySlot(EquipmentSlot paramEquipmentSlot);
  
  public abstract void setItemSlot(EquipmentSlot paramEquipmentSlot, ItemStack paramItemStack);
  
  public abstract HumanoidArm getMainArm();
}
