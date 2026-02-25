// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MinerCommand {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() reboot,
    required TResult Function() blinkLed,
    required TResult Function() stopBlink,
    required TResult Function(List<PoolConfig> pools) setPools,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? reboot,
    TResult? Function()? blinkLed,
    TResult? Function()? stopBlink,
    TResult? Function(List<PoolConfig> pools)? setPools,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? reboot,
    TResult Function()? blinkLed,
    TResult Function()? stopBlink,
    TResult Function(List<PoolConfig> pools)? setPools,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MinerCommand_Reboot value) reboot,
    required TResult Function(MinerCommand_BlinkLed value) blinkLed,
    required TResult Function(MinerCommand_StopBlink value) stopBlink,
    required TResult Function(MinerCommand_SetPools value) setPools,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MinerCommand_Reboot value)? reboot,
    TResult? Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult? Function(MinerCommand_StopBlink value)? stopBlink,
    TResult? Function(MinerCommand_SetPools value)? setPools,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MinerCommand_Reboot value)? reboot,
    TResult Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult Function(MinerCommand_StopBlink value)? stopBlink,
    TResult Function(MinerCommand_SetPools value)? setPools,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MinerCommandCopyWith<$Res> {
  factory $MinerCommandCopyWith(
    MinerCommand value,
    $Res Function(MinerCommand) then,
  ) = _$MinerCommandCopyWithImpl<$Res, MinerCommand>;
}

/// @nodoc
class _$MinerCommandCopyWithImpl<$Res, $Val extends MinerCommand>
    implements $MinerCommandCopyWith<$Res> {
  _$MinerCommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$MinerCommand_RebootImplCopyWith<$Res> {
  factory _$$MinerCommand_RebootImplCopyWith(
    _$MinerCommand_RebootImpl value,
    $Res Function(_$MinerCommand_RebootImpl) then,
  ) = __$$MinerCommand_RebootImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$MinerCommand_RebootImplCopyWithImpl<$Res>
    extends _$MinerCommandCopyWithImpl<$Res, _$MinerCommand_RebootImpl>
    implements _$$MinerCommand_RebootImplCopyWith<$Res> {
  __$$MinerCommand_RebootImplCopyWithImpl(
    _$MinerCommand_RebootImpl _value,
    $Res Function(_$MinerCommand_RebootImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$MinerCommand_RebootImpl extends MinerCommand_Reboot {
  const _$MinerCommand_RebootImpl() : super._();

  @override
  String toString() {
    return 'MinerCommand.reboot()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MinerCommand_RebootImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() reboot,
    required TResult Function() blinkLed,
    required TResult Function() stopBlink,
    required TResult Function(List<PoolConfig> pools) setPools,
  }) {
    return reboot();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? reboot,
    TResult? Function()? blinkLed,
    TResult? Function()? stopBlink,
    TResult? Function(List<PoolConfig> pools)? setPools,
  }) {
    return reboot?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? reboot,
    TResult Function()? blinkLed,
    TResult Function()? stopBlink,
    TResult Function(List<PoolConfig> pools)? setPools,
    required TResult orElse(),
  }) {
    if (reboot != null) {
      return reboot();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MinerCommand_Reboot value) reboot,
    required TResult Function(MinerCommand_BlinkLed value) blinkLed,
    required TResult Function(MinerCommand_StopBlink value) stopBlink,
    required TResult Function(MinerCommand_SetPools value) setPools,
  }) {
    return reboot(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MinerCommand_Reboot value)? reboot,
    TResult? Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult? Function(MinerCommand_StopBlink value)? stopBlink,
    TResult? Function(MinerCommand_SetPools value)? setPools,
  }) {
    return reboot?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MinerCommand_Reboot value)? reboot,
    TResult Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult Function(MinerCommand_StopBlink value)? stopBlink,
    TResult Function(MinerCommand_SetPools value)? setPools,
    required TResult orElse(),
  }) {
    if (reboot != null) {
      return reboot(this);
    }
    return orElse();
  }
}

abstract class MinerCommand_Reboot extends MinerCommand {
  const factory MinerCommand_Reboot() = _$MinerCommand_RebootImpl;
  const MinerCommand_Reboot._() : super._();
}

/// @nodoc
abstract class _$$MinerCommand_BlinkLedImplCopyWith<$Res> {
  factory _$$MinerCommand_BlinkLedImplCopyWith(
    _$MinerCommand_BlinkLedImpl value,
    $Res Function(_$MinerCommand_BlinkLedImpl) then,
  ) = __$$MinerCommand_BlinkLedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$MinerCommand_BlinkLedImplCopyWithImpl<$Res>
    extends _$MinerCommandCopyWithImpl<$Res, _$MinerCommand_BlinkLedImpl>
    implements _$$MinerCommand_BlinkLedImplCopyWith<$Res> {
  __$$MinerCommand_BlinkLedImplCopyWithImpl(
    _$MinerCommand_BlinkLedImpl _value,
    $Res Function(_$MinerCommand_BlinkLedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$MinerCommand_BlinkLedImpl extends MinerCommand_BlinkLed {
  const _$MinerCommand_BlinkLedImpl() : super._();

  @override
  String toString() {
    return 'MinerCommand.blinkLed()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MinerCommand_BlinkLedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() reboot,
    required TResult Function() blinkLed,
    required TResult Function() stopBlink,
    required TResult Function(List<PoolConfig> pools) setPools,
  }) {
    return blinkLed();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? reboot,
    TResult? Function()? blinkLed,
    TResult? Function()? stopBlink,
    TResult? Function(List<PoolConfig> pools)? setPools,
  }) {
    return blinkLed?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? reboot,
    TResult Function()? blinkLed,
    TResult Function()? stopBlink,
    TResult Function(List<PoolConfig> pools)? setPools,
    required TResult orElse(),
  }) {
    if (blinkLed != null) {
      return blinkLed();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MinerCommand_Reboot value) reboot,
    required TResult Function(MinerCommand_BlinkLed value) blinkLed,
    required TResult Function(MinerCommand_StopBlink value) stopBlink,
    required TResult Function(MinerCommand_SetPools value) setPools,
  }) {
    return blinkLed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MinerCommand_Reboot value)? reboot,
    TResult? Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult? Function(MinerCommand_StopBlink value)? stopBlink,
    TResult? Function(MinerCommand_SetPools value)? setPools,
  }) {
    return blinkLed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MinerCommand_Reboot value)? reboot,
    TResult Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult Function(MinerCommand_StopBlink value)? stopBlink,
    TResult Function(MinerCommand_SetPools value)? setPools,
    required TResult orElse(),
  }) {
    if (blinkLed != null) {
      return blinkLed(this);
    }
    return orElse();
  }
}

abstract class MinerCommand_BlinkLed extends MinerCommand {
  const factory MinerCommand_BlinkLed() = _$MinerCommand_BlinkLedImpl;
  const MinerCommand_BlinkLed._() : super._();
}

/// @nodoc
abstract class _$$MinerCommand_StopBlinkImplCopyWith<$Res> {
  factory _$$MinerCommand_StopBlinkImplCopyWith(
    _$MinerCommand_StopBlinkImpl value,
    $Res Function(_$MinerCommand_StopBlinkImpl) then,
  ) = __$$MinerCommand_StopBlinkImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$MinerCommand_StopBlinkImplCopyWithImpl<$Res>
    extends _$MinerCommandCopyWithImpl<$Res, _$MinerCommand_StopBlinkImpl>
    implements _$$MinerCommand_StopBlinkImplCopyWith<$Res> {
  __$$MinerCommand_StopBlinkImplCopyWithImpl(
    _$MinerCommand_StopBlinkImpl _value,
    $Res Function(_$MinerCommand_StopBlinkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$MinerCommand_StopBlinkImpl extends MinerCommand_StopBlink {
  const _$MinerCommand_StopBlinkImpl() : super._();

  @override
  String toString() {
    return 'MinerCommand.stopBlink()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MinerCommand_StopBlinkImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() reboot,
    required TResult Function() blinkLed,
    required TResult Function() stopBlink,
    required TResult Function(List<PoolConfig> pools) setPools,
  }) {
    return stopBlink();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? reboot,
    TResult? Function()? blinkLed,
    TResult? Function()? stopBlink,
    TResult? Function(List<PoolConfig> pools)? setPools,
  }) {
    return stopBlink?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? reboot,
    TResult Function()? blinkLed,
    TResult Function()? stopBlink,
    TResult Function(List<PoolConfig> pools)? setPools,
    required TResult orElse(),
  }) {
    if (stopBlink != null) {
      return stopBlink();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MinerCommand_Reboot value) reboot,
    required TResult Function(MinerCommand_BlinkLed value) blinkLed,
    required TResult Function(MinerCommand_StopBlink value) stopBlink,
    required TResult Function(MinerCommand_SetPools value) setPools,
  }) {
    return stopBlink(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MinerCommand_Reboot value)? reboot,
    TResult? Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult? Function(MinerCommand_StopBlink value)? stopBlink,
    TResult? Function(MinerCommand_SetPools value)? setPools,
  }) {
    return stopBlink?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MinerCommand_Reboot value)? reboot,
    TResult Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult Function(MinerCommand_StopBlink value)? stopBlink,
    TResult Function(MinerCommand_SetPools value)? setPools,
    required TResult orElse(),
  }) {
    if (stopBlink != null) {
      return stopBlink(this);
    }
    return orElse();
  }
}

abstract class MinerCommand_StopBlink extends MinerCommand {
  const factory MinerCommand_StopBlink() = _$MinerCommand_StopBlinkImpl;
  const MinerCommand_StopBlink._() : super._();
}

/// @nodoc
abstract class _$$MinerCommand_SetPoolsImplCopyWith<$Res> {
  factory _$$MinerCommand_SetPoolsImplCopyWith(
    _$MinerCommand_SetPoolsImpl value,
    $Res Function(_$MinerCommand_SetPoolsImpl) then,
  ) = __$$MinerCommand_SetPoolsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<PoolConfig> pools});
}

/// @nodoc
class __$$MinerCommand_SetPoolsImplCopyWithImpl<$Res>
    extends _$MinerCommandCopyWithImpl<$Res, _$MinerCommand_SetPoolsImpl>
    implements _$$MinerCommand_SetPoolsImplCopyWith<$Res> {
  __$$MinerCommand_SetPoolsImplCopyWithImpl(
    _$MinerCommand_SetPoolsImpl _value,
    $Res Function(_$MinerCommand_SetPoolsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? pools = null}) {
    return _then(
      _$MinerCommand_SetPoolsImpl(
        pools: null == pools
            ? _value._pools
            : pools // ignore: cast_nullable_to_non_nullable
                  as List<PoolConfig>,
      ),
    );
  }
}

/// @nodoc

class _$MinerCommand_SetPoolsImpl extends MinerCommand_SetPools {
  const _$MinerCommand_SetPoolsImpl({required final List<PoolConfig> pools})
    : _pools = pools,
      super._();

  final List<PoolConfig> _pools;
  @override
  List<PoolConfig> get pools {
    if (_pools is EqualUnmodifiableListView) return _pools;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pools);
  }

  @override
  String toString() {
    return 'MinerCommand.setPools(pools: $pools)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MinerCommand_SetPoolsImpl &&
            const DeepCollectionEquality().equals(other._pools, _pools));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_pools));

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MinerCommand_SetPoolsImplCopyWith<_$MinerCommand_SetPoolsImpl>
  get copyWith =>
      __$$MinerCommand_SetPoolsImplCopyWithImpl<_$MinerCommand_SetPoolsImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() reboot,
    required TResult Function() blinkLed,
    required TResult Function() stopBlink,
    required TResult Function(List<PoolConfig> pools) setPools,
  }) {
    return setPools(pools);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? reboot,
    TResult? Function()? blinkLed,
    TResult? Function()? stopBlink,
    TResult? Function(List<PoolConfig> pools)? setPools,
  }) {
    return setPools?.call(pools);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? reboot,
    TResult Function()? blinkLed,
    TResult Function()? stopBlink,
    TResult Function(List<PoolConfig> pools)? setPools,
    required TResult orElse(),
  }) {
    if (setPools != null) {
      return setPools(pools);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MinerCommand_Reboot value) reboot,
    required TResult Function(MinerCommand_BlinkLed value) blinkLed,
    required TResult Function(MinerCommand_StopBlink value) stopBlink,
    required TResult Function(MinerCommand_SetPools value) setPools,
  }) {
    return setPools(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MinerCommand_Reboot value)? reboot,
    TResult? Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult? Function(MinerCommand_StopBlink value)? stopBlink,
    TResult? Function(MinerCommand_SetPools value)? setPools,
  }) {
    return setPools?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MinerCommand_Reboot value)? reboot,
    TResult Function(MinerCommand_BlinkLed value)? blinkLed,
    TResult Function(MinerCommand_StopBlink value)? stopBlink,
    TResult Function(MinerCommand_SetPools value)? setPools,
    required TResult orElse(),
  }) {
    if (setPools != null) {
      return setPools(this);
    }
    return orElse();
  }
}

abstract class MinerCommand_SetPools extends MinerCommand {
  const factory MinerCommand_SetPools({required final List<PoolConfig> pools}) =
      _$MinerCommand_SetPoolsImpl;
  const MinerCommand_SetPools._() : super._();

  List<PoolConfig> get pools;

  /// Create a copy of MinerCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MinerCommand_SetPoolsImplCopyWith<_$MinerCommand_SetPoolsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
