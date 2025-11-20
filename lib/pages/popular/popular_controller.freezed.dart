// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'popular_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PopularState {
  String get currentTag => throw _privateConstructorUsedError;
  List<BangumiItem> get bangumiList =>
      throw _privateConstructorUsedError; // 按标签获取的番组
  List<BangumiItem> get trendList =>
      throw _privateConstructorUsedError; // 热门趋势番组
  Map<String, List<BangumiItem>> get tagCache =>
      throw _privateConstructorUsedError; // 标签数据缓存
  double get scrollOffset => throw _privateConstructorUsedError;
  bool get isLoadingMore => throw _privateConstructorUsedError;
  bool get isTimeOut => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PopularStateCopyWith<PopularState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PopularStateCopyWith<$Res> {
  factory $PopularStateCopyWith(
          PopularState value, $Res Function(PopularState) then) =
      _$PopularStateCopyWithImpl<$Res, PopularState>;
  @useResult
  $Res call(
      {String currentTag,
      List<BangumiItem> bangumiList,
      List<BangumiItem> trendList,
      Map<String, List<BangumiItem>> tagCache,
      double scrollOffset,
      bool isLoadingMore,
      bool isTimeOut});
}

/// @nodoc
class _$PopularStateCopyWithImpl<$Res, $Val extends PopularState>
    implements $PopularStateCopyWith<$Res> {
  _$PopularStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentTag = null,
    Object? bangumiList = null,
    Object? trendList = null,
    Object? tagCache = null,
    Object? scrollOffset = null,
    Object? isLoadingMore = null,
    Object? isTimeOut = null,
  }) {
    return _then(_value.copyWith(
      currentTag: null == currentTag
          ? _value.currentTag
          : currentTag // ignore: cast_nullable_to_non_nullable
              as String,
      bangumiList: null == bangumiList
          ? _value.bangumiList
          : bangumiList // ignore: cast_nullable_to_non_nullable
              as List<BangumiItem>,
      trendList: null == trendList
          ? _value.trendList
          : trendList // ignore: cast_nullable_to_non_nullable
              as List<BangumiItem>,
      tagCache: null == tagCache
          ? _value.tagCache
          : tagCache // ignore: cast_nullable_to_non_nullable
              as Map<String, List<BangumiItem>>,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimeOut: null == isTimeOut
          ? _value.isTimeOut
          : isTimeOut // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PopularStateImplCopyWith<$Res>
    implements $PopularStateCopyWith<$Res> {
  factory _$$PopularStateImplCopyWith(
          _$PopularStateImpl value, $Res Function(_$PopularStateImpl) then) =
      __$$PopularStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String currentTag,
      List<BangumiItem> bangumiList,
      List<BangumiItem> trendList,
      Map<String, List<BangumiItem>> tagCache,
      double scrollOffset,
      bool isLoadingMore,
      bool isTimeOut});
}

/// @nodoc
class __$$PopularStateImplCopyWithImpl<$Res>
    extends _$PopularStateCopyWithImpl<$Res, _$PopularStateImpl>
    implements _$$PopularStateImplCopyWith<$Res> {
  __$$PopularStateImplCopyWithImpl(
      _$PopularStateImpl _value, $Res Function(_$PopularStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentTag = null,
    Object? bangumiList = null,
    Object? trendList = null,
    Object? tagCache = null,
    Object? scrollOffset = null,
    Object? isLoadingMore = null,
    Object? isTimeOut = null,
  }) {
    return _then(_$PopularStateImpl(
      currentTag: null == currentTag
          ? _value.currentTag
          : currentTag // ignore: cast_nullable_to_non_nullable
              as String,
      bangumiList: null == bangumiList
          ? _value._bangumiList
          : bangumiList // ignore: cast_nullable_to_non_nullable
              as List<BangumiItem>,
      trendList: null == trendList
          ? _value._trendList
          : trendList // ignore: cast_nullable_to_non_nullable
              as List<BangumiItem>,
      tagCache: null == tagCache
          ? _value._tagCache
          : tagCache // ignore: cast_nullable_to_non_nullable
              as Map<String, List<BangumiItem>>,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimeOut: null == isTimeOut
          ? _value.isTimeOut
          : isTimeOut // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$PopularStateImpl implements _PopularState {
  const _$PopularStateImpl(
      {this.currentTag = '',
      final List<BangumiItem> bangumiList = const [],
      final List<BangumiItem> trendList = const [],
      final Map<String, List<BangumiItem>> tagCache = const {},
      this.scrollOffset = 0.0,
      this.isLoadingMore = false,
      this.isTimeOut = false})
      : _bangumiList = bangumiList,
        _trendList = trendList,
        _tagCache = tagCache;

  @override
  @JsonKey()
  final String currentTag;
  final List<BangumiItem> _bangumiList;
  @override
  @JsonKey()
  List<BangumiItem> get bangumiList {
    if (_bangumiList is EqualUnmodifiableListView) return _bangumiList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bangumiList);
  }

// 按标签获取的番组
  final List<BangumiItem> _trendList;
// 按标签获取的番组
  @override
  @JsonKey()
  List<BangumiItem> get trendList {
    if (_trendList is EqualUnmodifiableListView) return _trendList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trendList);
  }

// 热门趋势番组
  final Map<String, List<BangumiItem>> _tagCache;
// 热门趋势番组
  @override
  @JsonKey()
  Map<String, List<BangumiItem>> get tagCache {
    if (_tagCache is EqualUnmodifiableMapView) return _tagCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_tagCache);
  }

// 标签数据缓存
  @override
  @JsonKey()
  final double scrollOffset;
  @override
  @JsonKey()
  final bool isLoadingMore;
  @override
  @JsonKey()
  final bool isTimeOut;

  @override
  String toString() {
    return 'PopularState(currentTag: $currentTag, bangumiList: $bangumiList, trendList: $trendList, tagCache: $tagCache, scrollOffset: $scrollOffset, isLoadingMore: $isLoadingMore, isTimeOut: $isTimeOut)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PopularStateImpl &&
            (identical(other.currentTag, currentTag) ||
                other.currentTag == currentTag) &&
            const DeepCollectionEquality()
                .equals(other._bangumiList, _bangumiList) &&
            const DeepCollectionEquality()
                .equals(other._trendList, _trendList) &&
            const DeepCollectionEquality().equals(other._tagCache, _tagCache) &&
            (identical(other.scrollOffset, scrollOffset) ||
                other.scrollOffset == scrollOffset) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.isTimeOut, isTimeOut) ||
                other.isTimeOut == isTimeOut));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      currentTag,
      const DeepCollectionEquality().hash(_bangumiList),
      const DeepCollectionEquality().hash(_trendList),
      const DeepCollectionEquality().hash(_tagCache),
      scrollOffset,
      isLoadingMore,
      isTimeOut);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PopularStateImplCopyWith<_$PopularStateImpl> get copyWith =>
      __$$PopularStateImplCopyWithImpl<_$PopularStateImpl>(this, _$identity);
}

abstract class _PopularState implements PopularState {
  const factory _PopularState(
      {final String currentTag,
      final List<BangumiItem> bangumiList,
      final List<BangumiItem> trendList,
      final Map<String, List<BangumiItem>> tagCache,
      final double scrollOffset,
      final bool isLoadingMore,
      final bool isTimeOut}) = _$PopularStateImpl;

  @override
  String get currentTag;
  @override
  List<BangumiItem> get bangumiList;
  @override // 按标签获取的番组
  List<BangumiItem> get trendList;
  @override // 热门趋势番组
  Map<String, List<BangumiItem>> get tagCache;
  @override // 标签数据缓存
  double get scrollOffset;
  @override
  bool get isLoadingMore;
  @override
  bool get isTimeOut;
  @override
  @JsonKey(ignore: true)
  _$$PopularStateImplCopyWith<_$PopularStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
