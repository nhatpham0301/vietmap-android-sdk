#import "MGLStyle_Private.h"

#import "MGLMapView_Private.h"
#import "MGLStyleLayer.h"
#import "MGLStyleLayer_Private.h"
#import "MGLFillStyleLayer.h"
#import "MGLFillExtrusionStyleLayer.h"
#import "MGLLineStyleLayer.h"
#import "MGLCircleStyleLayer.h"
#import "MGLSymbolStyleLayer.h"
#import "MGLHeatmapStyleLayer.h"
#import "MGLHillshadeStyleLayer.h"
#import "MGLRasterStyleLayer.h"
#import "MGLBackgroundStyleLayer.h"
#import "MGLOpenGLStyleLayer.h"
#import "MGLStyleLayerManager.h"

#import "MGLSource.h"
#import "MGLSource_Private.h"
#import "MGLLight_Private.h"
#import "MGLTileSource_Private.h"
#import "MGLVectorTileSource_Private.h"
#import "MGLRasterTileSource.h"
#import "MGLRasterDEMSource.h"
#import "MGLShapeSource.h"
#import "MGLImageSource.h"

#import "MGLAttributionInfo_Private.h"
#import "MGLLoggingConfiguration_Private.h"

#include <mbgl/map/map.hpp>
#include <mbgl/style/style.hpp>
#include <mbgl/style/image.hpp>
#include <mbgl/style/light.hpp>
#include <mbgl/style/sources/geojson_source.hpp>
#include <mbgl/style/sources/vector_source.hpp>
#include <mbgl/style/sources/raster_source.hpp>
#include <mbgl/style/sources/raster_dem_source.hpp>
#include <mbgl/style/sources/image_source.hpp>

#import "NSDate+MGLAdditions.h"

#if TARGET_OS_IPHONE
    #import "UIImage+MGLAdditions.h"
#else
    #import "NSImage+MGLAdditions.h"
#endif

const MGLExceptionName MGLInvalidStyleURLException = @"MGLInvalidStyleURLException";
const MGLExceptionName MGLRedundantLayerException = @"MGLRedundantLayerException";
const MGLExceptionName MGLRedundantLayerIdentifierException = @"MGLRedundantLayerIdentifierException";
const MGLExceptionName MGLRedundantSourceException = @"MGLRedundantSourceException";
const MGLExceptionName MGLRedundantSourceIdentifierException = @"MGLRedundantSourceIdentifierException";

/**
 Model class for localization changes.
 */
@interface MGLTextLanguage: NSObject
@property (strong, nonatomic) NSString *originalTextField;
@property (strong, nonatomic) NSString *updatedTextField;

- (instancetype)initWithTextLanguage:(NSString *)originalTextField updatedTextField:(NSString *)updatedTextField;

@end

@implementation MGLTextLanguage
- (instancetype)initWithTextLanguage:(NSString *)originalTextField updatedTextField:(NSString *)updatedTextField
{
    if (self = [super init]) {
        _originalTextField = originalTextField;
        _updatedTextField = updatedTextField;
    }
    return self;
}
@end

@interface MGLStyle()

@property (nonatomic, readonly, weak) id <MGLStylable> stylable;
@property (nonatomic, readonly) mbgl::style::Style *rawStyle;
@property (readonly, copy, nullable) NSURL *URL;
@property (nonatomic, readwrite, strong) NSMutableDictionary<NSString *, MGLOpenGLStyleLayer *> *openGLLayers;
@property (nonatomic) NSMutableDictionary<NSString *, NSDictionary<NSObject *, MGLTextLanguage *> *> *localizedLayersByIdentifier;

@end

@implementation MGLStyle

// MARK: Predefined style URLs

+ (NSArray<MGLDefaultStyle*>*) predefinedStyles {
    return MGLSettings.tileServerOptions.defaultStyles;
}

+ (MGLDefaultStyle*) defaultStyle {
    MGLTileServerOptions* opts = MGLSettings.tileServerOptions;
    return opts.defaultStyle;
}

+ (NSURL*) defaultStyleURL {
    MGLDefaultStyle* styleDefinition = [MGLStyle defaultStyle];
    if (styleDefinition != nil){
        return styleDefinition.url;
    }
    
    return nil;
}

+ (MGLDefaultStyle*) predefinedStyle:(NSString*)withStyleName {
    for (MGLDefaultStyle* style in MGLSettings.tileServerOptions.defaultStyles) {
        if ([style.name isEqualToString:withStyleName]) {
            return style;
        }
    }
    return nil;
}

// MARK: -

- (instancetype)initWithRawStyle:(mbgl::style::Style *)rawStyle stylable:(id <MGLStylable>)stylable {
    MGLLogInfo(@"Initializing %@ with stylable: %@", NSStringFromClass([self class]), stylable);
    if (self = [super init]) {
        _stylable = stylable;
        _rawStyle = rawStyle;
        _openGLLayers = [NSMutableDictionary dictionary];
        _localizedLayersByIdentifier = [NSMutableDictionary dictionary];
        MGLLogDebug(@"Initializing with style name: %@ stylable: %@", self.name, stylable);
    }
    return self;
}

- (NSURL *)URL {
    return [NSURL URLWithString:@(self.rawStyle->getURL().c_str())];
}

- (NSString *)name {
    std::string name = self.rawStyle->getName();
    return name.empty() ? nil : @(name.c_str());
}

// MARK: Sources

- (NSSet<__kindof MGLSource *> *)sources {
    auto rawSources = self.rawStyle->getSources();
    NSMutableSet<__kindof MGLSource *> *sources = [NSMutableSet setWithCapacity:rawSources.size()];
    for (auto rawSource = rawSources.begin(); rawSource != rawSources.end(); ++rawSource) {
        MGLSource *source = [self sourceFromMBGLSource:*rawSource];
        [sources addObject:source];
    }
    return sources;
}

- (void)setSources:(NSSet<__kindof MGLSource *> *)sources {
    MGLLogDebug(@"Setting: %lu sources", sources.count);
    for (MGLSource *source in self.sources) {
        [self removeSource:source];
    }
    for (MGLSource *source in sources) {
        [self addSource:source];
    }
}

- (NSUInteger)countOfSources {
    return self.rawStyle->getSources().size();
}

- (MGLSource *)memberOfSources:(MGLSource *)object {
    return [self sourceWithIdentifier:object.identifier];
}

- (MGLSource *)sourceWithIdentifier:(NSString *)identifier
{
    MGLLogDebug(@"Querying source with identifier: %@", identifier);
    auto rawSource = self.rawStyle->getSource(identifier.UTF8String);
    
    return rawSource ? [self sourceFromMBGLSource:rawSource] : nil;
}

- (MGLSource *)sourceFromMBGLSource:(mbgl::style::Source *)rawSource {
    if (MGLSource *source = rawSource->peer.has_value() ? rawSource->peer.get<SourceWrapper>().source : nil) {
        return source;
    }

    // TODO: Fill in options specific to the respective source classes
    // https://github.com/mapbox/mapbox-gl-native/issues/6584
    if (auto vectorSource = rawSource->as<mbgl::style::VectorSource>()) {
        return [[MGLVectorTileSource alloc] initWithRawSource:vectorSource stylable:self.stylable];
    } else if (auto geoJSONSource = rawSource->as<mbgl::style::GeoJSONSource>()) {
        return [[MGLShapeSource alloc] initWithRawSource:geoJSONSource stylable:self.stylable];
    } else if (auto rasterSource = rawSource->as<mbgl::style::RasterSource>()) {
        return [[MGLRasterTileSource alloc] initWithRawSource:rasterSource stylable:self.stylable];
    } else if (auto rasterDEMSource = rawSource->as<mbgl::style::RasterDEMSource>()) {
        return [[MGLRasterDEMSource alloc] initWithRawSource:rasterDEMSource stylable:self.stylable];
    } else if (auto imageSource = rawSource->as<mbgl::style::ImageSource>()) {
        return [[MGLImageSource alloc] initWithRawSource:imageSource stylable:self.stylable];
    } else {
        return [[MGLSource alloc] initWithRawSource:rawSource stylable:self.stylable];
    }
}

- (void)addSource:(MGLSource *)source
{
    MGLLogDebug(@"Adding source: %@", source);
    if (!source.rawSource) {
        [NSException raise:NSInvalidArgumentException format:
         @"The source %@ cannot be added to the style. "
         @"Make sure the source was created as a member of a concrete subclass of MGLSource.",
         source];
    }

    try {
        [source addToStylable:self.stylable];
    } catch (std::runtime_error & err) {
        [NSException raise:MGLRedundantSourceIdentifierException format:@"%s", err.what()];
    }
}

- (void)removeSource:(MGLSource *)source
{
    [self removeSource:source error:nil];
}

- (BOOL)removeSource:(MGLSource *)source error:(NSError * __nullable * __nullable)outError {
    MGLLogDebug(@"Removing source: %@", source);
    
    if (!source.rawSource) {
        NSString *errorMessage = [NSString stringWithFormat:
                                  @"The source %@ cannot be removed from the style. "
                                  @"Make sure the source was created as a member of a concrete subclass of MGLSource."
                                  @"Automatic re-addition of sources after style changes is not currently supported.",
                                  source];
        
        if (outError) {
            *outError = [NSError errorWithDomain:MGLErrorDomain
                                            code:MGLErrorCodeSourceCannotBeRemovedFromStyle
                                        userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];
            return NO;
        }
        else {
            [NSException raise:NSInvalidArgumentException format:@"%@", errorMessage];
        }
    }
    
    return [source removeFromStylable:self.stylable error:outError];
}


- (nullable NSArray<MGLAttributionInfo *> *)attributionInfosWithFontSize:(CGFloat)fontSize linkColor:(nullable MGLColor *)linkColor {
    // It’d be incredibly convenient to use -sources here, but this operation
    // depends on the sources being sorted in ascending order by creation, as
    // with the std::vector used in mbgl.
    auto rawSources = self.rawStyle->getSources();
    NSMutableArray *infos = [NSMutableArray arrayWithCapacity:rawSources.size()];
    for (auto rawSource = rawSources.begin(); rawSource != rawSources.end(); ++rawSource) {
        MGLTileSource *source = (MGLTileSource *)[self sourceFromMBGLSource:*rawSource];
        if (![source isKindOfClass:[MGLTileSource class]]) {
            continue;
        }

        NSArray *tileSetInfos = [source attributionInfosWithFontSize:fontSize linkColor:linkColor];
        [infos growArrayByAddingAttributionInfosFromArray:tileSetInfos];
    }
    return infos;
}

// MARK: Style layers

- (NSArray<__kindof MGLStyleLayer *> *)layers
{
    auto layers = self.rawStyle->getLayers();
    NSMutableArray<__kindof MGLStyleLayer *> *styleLayers = [NSMutableArray arrayWithCapacity:layers.size()];
    for (auto layer : layers) {
        MGLStyleLayer *styleLayer = [self layerFromMBGLLayer:layer];
        [styleLayers addObject:styleLayer];
    }
    return styleLayers;
}

- (void)setLayers:(NSArray<__kindof MGLStyleLayer *> *)layers {
    MGLLogDebug(@"Setting: %lu layers", layers.count);
    for (MGLStyleLayer *layer in self.layers) {
        [self removeLayer:layer];
    }
    for (MGLStyleLayer *layer in layers) {
        [self addLayer:layer];
    }
}

- (NSUInteger)countOfLayers
{
    return self.rawStyle->getLayers().size();
}

- (MGLStyleLayer *)objectInLayersAtIndex:(NSUInteger)index
{
    auto layers = self.rawStyle->getLayers();
    if (index >= layers.size()) {
        [NSException raise:NSRangeException
                    format:@"No style layer at index %lu.", (unsigned long)index];
        return nil;
    }
    auto layer = layers.at(index);
    return [self layerFromMBGLLayer:layer];
}

- (void)getLayers:(MGLStyleLayer **)buffer range:(NSRange)inRange
{
    auto layers = self.rawStyle->getLayers();
    if (NSMaxRange(inRange) > layers.size()) {
        [NSException raise:NSRangeException
                    format:@"Style layer range %@ is out of bounds.", NSStringFromRange(inRange)];
    }
    NSUInteger i = 0;
    for (auto layer = *(layers.rbegin() + inRange.location); i < inRange.length; ++layer, ++i) {
        MGLStyleLayer *styleLayer = [self layerFromMBGLLayer:layer];
        buffer[i] = styleLayer;
    }
}

- (void)insertObject:(MGLStyleLayer *)styleLayer inLayersAtIndex:(NSUInteger)index
{
    if (!styleLayer.rawLayer) {
        [NSException raise:NSInvalidArgumentException format:
         @"The style layer %@ cannot be inserted into the style. "
         @"Make sure the style layer was created as a member of a concrete subclass of MGLStyleLayer.",
         styleLayer];
    }
    auto layers = self.rawStyle->getLayers();
    if (index > layers.size()) {
        [NSException raise:NSRangeException
                    format:@"Cannot insert style layer at out-of-bounds index %lu.", (unsigned long)index];
    } else if (index == 0) {
        try {
            MGLStyleLayer *sibling = layers.size() ? [self layerFromMBGLLayer:layers.at(0)] : nil;
            [styleLayer addToStyle:self belowLayer:sibling];
        } catch (const std::runtime_error & err) {
            [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
        }
    } else {
        try {
            MGLStyleLayer *sibling = [self layerFromMBGLLayer:layers.at(index)];
            [styleLayer addToStyle:self belowLayer:sibling];
        } catch (std::runtime_error & err) {
            [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
        }
    }
}

- (void)removeObjectFromLayersAtIndex:(NSUInteger)index
{
    auto layers = self.rawStyle->getLayers();
    if (index >= layers.size()) {
        [NSException raise:NSRangeException
                    format:@"Cannot remove style layer at out-of-bounds index %lu.", (unsigned long)index];
    }
    auto layer = layers.at(index);
    MGLStyleLayer *styleLayer = [self layerFromMBGLLayer:layer];
    [styleLayer removeFromStyle:self];
}

- (MGLStyleLayer *)layerFromMBGLLayer:(mbgl::style::Layer *)rawLayer
{
    NSParameterAssert(rawLayer);

    if (MGLStyleLayer *layer = rawLayer->peer.has_value() ? rawLayer->peer.get<LayerWrapper>().layer : nil) {
        return layer;
    }

    return mbgl::LayerManagerDarwin::get()->createPeer(rawLayer);
}

- (MGLStyleLayer *)layerWithIdentifier:(NSString *)identifier
{
    MGLLogDebug(@"Querying layerWithIdentifier: %@", identifier);
    auto mbglLayer = self.rawStyle->getLayer(identifier.UTF8String);
    return mbglLayer ? [self layerFromMBGLLayer:mbglLayer] : nil;
}

- (void)removeLayer:(MGLStyleLayer *)layer
{
    MGLLogDebug(@"Removing layer: %@", layer);
    if (!layer.rawLayer) {
        [NSException raise:NSInvalidArgumentException format:
         @"The style layer %@ cannot be removed from the style. "
         @"Make sure the style layer was created as a member of a concrete subclass of MGLStyleLayer.",
         layer];
    }
    [self willChangeValueForKey:@"layers"];
    [layer removeFromStyle:self];
    [self didChangeValueForKey:@"layers"];
}

- (void)addLayer:(MGLStyleLayer *)layer
{
    MGLLogDebug(@"Adding layer: %@", layer);
    if (!layer.rawLayer) {
        [NSException raise:NSInvalidArgumentException format:
         @"The style layer %@ cannot be added to the style. "
         @"Make sure the style layer was created as a member of a concrete subclass of MGLStyleLayer.",
         layer];
    }
    [self willChangeValueForKey:@"layers"];
    try {
        [layer addToStyle:self belowLayer:nil];
    } catch (std::runtime_error & err) {
        [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
    }
    [self didChangeValueForKey:@"layers"];
}

- (void)insertLayer:(MGLStyleLayer *)layer atIndex:(NSUInteger)index {
    [self insertObject:layer inLayersAtIndex:index];
}

- (void)insertLayer:(MGLStyleLayer *)layer belowLayer:(MGLStyleLayer *)sibling
{
    MGLLogDebug(@"Inseting layer: %@ belowLayer: %@", layer, sibling);
    if (!layer.rawLayer) {
        [NSException raise:NSInvalidArgumentException
                    format:
         @"The style layer %@ cannot be added to the style. "
         @"Make sure the style layer was created as a member of a concrete subclass of MGLStyleLayer.",
         layer];
    }
    if (!sibling.rawLayer) {
        [NSException raise:NSInvalidArgumentException
                    format:
         @"A style layer cannot be placed below %@ in the style. "
         @"Make sure sibling was obtained using -[MGLStyle layerWithIdentifier:].",
         sibling];
    }
    [self willChangeValueForKey:@"layers"];
    try {
        [layer addToStyle:self belowLayer:sibling];
    } catch (std::runtime_error & err) {
        [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
    }
    [self didChangeValueForKey:@"layers"];
}

- (void)insertLayer:(MGLStyleLayer *)layer aboveLayer:(MGLStyleLayer *)sibling {
    MGLLogDebug(@"Inseting layer: %@ aboveLayer: %@", layer, sibling);
    if (!layer.rawLayer) {
        [NSException raise:NSInvalidArgumentException
                    format:
         @"The style layer %@ cannot be added to the style. "
         @"Make sure the style layer was created as a member of a concrete subclass of MGLStyleLayer.",
         layer];
    }
    if (!sibling.rawLayer) {
        [NSException raise:NSInvalidArgumentException
                    format:
         @"A style layer cannot be placed above %@ in the style. "
         @"Make sure sibling was obtained using -[MGLStyle layerWithIdentifier:].",
         sibling];
    }

    auto layers = self.rawStyle->getLayers();
    std::string siblingIdentifier = sibling.identifier.UTF8String;
    NSUInteger index = 0;
    for (auto siblingLayer : layers) {
        if (siblingLayer->getID() == siblingIdentifier) {
            break;
        }
        index++;
    }

    [self willChangeValueForKey:@"layers"];
    if (index + 1 > layers.size()) {
        [NSException raise:NSInvalidArgumentException
                    format:
         @"A style layer cannot be placed above %@ in the style. "
         @"Make sure sibling was obtained using -[MGLStyle layerWithIdentifier:].",
         sibling];
    } else if (index + 1 == layers.size()) {
        try {
            [layer addToStyle:self belowLayer:nil];
        } catch (std::runtime_error & err) {
            [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
        }
    } else {
        MGLStyleLayer *nextSibling = [self layerFromMBGLLayer:layers.at(index + 1)];
        try {
            [layer addToStyle:self belowLayer:nextSibling];
        } catch (std::runtime_error & err) {
            [NSException raise:MGLRedundantLayerIdentifierException format:@"%s", err.what()];
        }
    }
    [self didChangeValueForKey:@"layers"];
}

// MARK: Style images

- (void)setImage:(MGLImage *)image forName:(NSString *)name
{
    MGLLogDebug(@"Setting image: %@ forName: %@", image, name);
    if (!image) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot assign nil image to “%@”.", name];
    }
    if (!name) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot assign image %@ to a nil name.", image];
    }

    self.rawStyle->addImage([image mgl_styleImageWithIdentifier:name]);
}

- (void)removeImageForName:(NSString *)name
{
    MGLLogDebug(@"Removing imageForName: %@", name);
    if (!name) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot remove image with nil name."];
    }

    self.rawStyle->removeImage([name UTF8String]);
}

- (MGLImage *)imageForName:(NSString *)name
{
    MGLLogDebug(@"Querying imageForName: %@", name);
    if (!name) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Cannot get image with nil name."];
    }

    auto styleImage = self.rawStyle->getImage([name UTF8String]);
    return styleImage ? [[MGLImage alloc] initWithMGLStyleImage:*styleImage] : nil;
}

// MARK: Style transitions

- (void)setTransition:(MGLTransition)transition
{
    self.rawStyle->setTransitionOptions(MGLOptionsFromTransition(transition));
}

- (MGLTransition)transition
{
    const mbgl::style::TransitionOptions transitionOptions = self.rawStyle->getTransitionOptions();
    
    return MGLTransitionFromOptions(transitionOptions);
}

- (void)setPerformsPlacementTransitions:(BOOL)performsPlacementTransitions
{
    mbgl::style::TransitionOptions transitionOptions = self.rawStyle->getTransitionOptions();
    transitionOptions.enablePlacementTransitions = static_cast<bool>(performsPlacementTransitions);
    self.rawStyle->setTransitionOptions(transitionOptions);
}

- (BOOL)performsPlacementTransitions
{
    mbgl::style::TransitionOptions transitionOptions = self.rawStyle->getTransitionOptions();
    return transitionOptions.enablePlacementTransitions;
}

// MARK: Style light

- (void)setLight:(MGLLight *)light
{
    std::unique_ptr<mbgl::style::Light> mbglLight = std::make_unique<mbgl::style::Light>([light mbglLight]);
    self.rawStyle->setLight(std::move(mbglLight));
}

- (MGLLight *)light
{
    auto mbglLight = self.rawStyle->getLight();
    MGLLight *light = [[MGLLight alloc] initWithMBGLLight:mbglLight];
    return light;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; name = %@, URL = %@>",
            NSStringFromClass([self class]), (void *)self,
            self.name ? [NSString stringWithFormat:@"\"%@\"", self.name] : self.name,
            self.URL ? [NSString stringWithFormat:@"\"%@\"", self.URL] : self.URL];
}

// MARK: Mapbox Streets source introspection

- (void)localizeLabelsIntoLocale:(nullable NSLocale *)locale {
    NSSet<MGLVectorTileSource *> *streetsSources =
        [self.sources filteredSetUsingPredicate:
         [NSPredicate predicateWithBlock:^BOOL(MGLVectorTileSource * _Nullable source, NSDictionary<NSString *, id> * _Nullable bindings) {
            return [source isKindOfClass:[MGLVectorTileSource class]] && [source isMapboxStreets];
        }]];
    NSSet<NSString *> *streetsSourceIdentifiers = [streetsSources valueForKey:@"identifier"];
    
    for (MGLSymbolStyleLayer *layer in self.layers) {
        if (![layer isKindOfClass:[MGLSymbolStyleLayer class]]) {
            continue;
        }
        if (![streetsSourceIdentifiers containsObject:layer.sourceIdentifier]) {
            continue;
        }
        
        NSExpression *text = layer.text;
        NSExpression *localizedText = [text mgl_expressionLocalizedIntoLocale:locale];
        if (![localizedText isEqual:text]) {
            layer.text = localizedText;
        }
    }
}

- (NSSet<MGLVectorTileSource *> *)mapboxStreetsSources {
    return [self.sources objectsPassingTest:^BOOL (__kindof MGLVectorTileSource * _Nonnull source, BOOL * _Nonnull stop) {
        return [source isKindOfClass:[MGLVectorTileSource class]] && source.mapboxStreets;
    }];
}

- (NSArray<MGLStyleLayer *> *)placeStyleLayers {
    NSSet *streetsSourceIdentifiers = [self.mapboxStreetsSources valueForKey:@"identifier"];
    
    NSSet *placeSourceLayerIdentifiers = [NSSet setWithObjects:@"marine_label", @"country_label", @"state_label", @"place_label", @"water_label", @"poi_label", @"rail_station_label", @"mountain_peak_label", @"natural_label", @"transit_stop_label", nil];
    NSPredicate *isPlacePredicate = [NSPredicate predicateWithBlock:^BOOL (MGLVectorStyleLayer * _Nullable layer, NSDictionary<NSString *, id> * _Nullable bindings) {
        return [layer isKindOfClass:[MGLVectorStyleLayer class]] && [streetsSourceIdentifiers containsObject:layer.sourceIdentifier] && [placeSourceLayerIdentifiers containsObject:layer.sourceLayerIdentifier];
    }];
    return [self.layers filteredArrayUsingPredicate:isPlacePredicate];
}

- (NSArray<MGLStyleLayer *> *)roadStyleLayers {
    NSSet *streetsSourceIdentifiers = [self.mapboxStreetsSources valueForKey:@"identifier"];

    NSSet *roadStyleLayerIdentifiers = [NSSet setWithObjects:@"road_label", @"road", nil];
    NSPredicate *isPlacePredicate = [NSPredicate predicateWithBlock:^BOOL (MGLVectorStyleLayer * _Nullable layer, NSDictionary<NSString *, id> * _Nullable bindings) {
        return [layer isKindOfClass:[MGLVectorStyleLayer class]] && [streetsSourceIdentifiers containsObject:layer.sourceIdentifier] && [roadStyleLayerIdentifiers containsObject:layer.sourceLayerIdentifier];
    }];
    return [self.layers filteredArrayUsingPredicate:isPlacePredicate];
}

@end
