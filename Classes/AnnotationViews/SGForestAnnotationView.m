//
//  SGForestAnnotationView.m
//  SGiPhoneSDK
//
//  Created by Derek Smith on 10/13/09.
//  Copyright 2009 SimpleGeo. All rights reserved.
//

#import "SGForestAnnotationView.h"

enum SGForestCreature {
    
    kSGForestCreature_Bat = 0,
    kSGForestCreature_Dog,
    kSGForestCreature_Duck, 
    kSGForestCreature_Elephant,
    kSGForestCreature_Fox,
    kSGForestCreature_Frog,
    kSGForestCreature_Kitty,
    kSGForestCreature_Lion,    
    kSGForestCreature_Panda,
    kSGForestCreature_Penguin,
    kSGForestCreature_Rat,
    kSGForestCreature_Tuqui,
    
    kSGForestCreature_Amount
};

typedef NSInteger SGForestCreature;


@interface SGForestAnnotationView (Private)

- (void) makeCreature;
- (NSString*) makeCreatureChoice;

@end


@implementation SGForestAnnotationView

@dynamic big;

- (id) initAtPoint:(CGPoint)pt reuseIdentifier:(NSString *)identifier
{
    if(self = [super initAtPoint:pt reuseIdentifier:identifier]) {
        
        self.inspectorType = kSGAnnotationViewInspectorType_Photo;
        
        [self prepareForReuse];
        
        [self setBig:NO];
    }
    
    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (id<SGAnnotation>) annotation
{
    self.detailedLabel.text = [NSString stringWithFormat:@"%.1fm", self.distance / 10.0];
    
    [self setNeedsLayout];
    
    return [super annotation];
}

- (void) setBig:(BOOL)newBig
{
    big = newBig;
    
    self.closeButton.hidden = !big;
    
    if(big) {
     
        self.photoImageView.image = creatureImage;
        self.targetImageView.image = nil;
        self.inspectorType = kSGAnnotationViewInspectorType_Photo;
        
    } else {
        
        self.photoImageView.image = nil;
        self.targetImageView.image = creatureImage;
        self.inspectorType = kSGAnnotationViewInspectorType_Message;
    }
    
    [self setNeedsLayout];
}

- (BOOL) big
{
    return big;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
        
    [self makeCreature];

    [self inspectView:YES];        
}

- (void) makeCreature
{
    NSString* creatureName = [self makeCreatureChoice];
    
    if(creatureImage)
        [creatureImage release];
    
    creatureImage = [[UIImage imageNamed:[creatureName stringByAppendingString:@".png"]] retain];
    
    self.photoImageView.image = creatureImage;
    [self.radarTargetButton setImage:[UIImage imageNamed:[creatureName stringByAppendingString:@"Mini.png"]]
                            forState:UIControlStateNormal];
    
    
    // Layout the title label differently becuase the default implementation
    // will indent it based on the size of the targetImageView.
    self.titleLabel.text = [@"The " stringByAppendingString:creatureName];
    
    self.messageLabel.text = [NSString stringWithFormat:@"This is a %@. A what? A %@. A what? A %@. Oh a %@!",
                              creatureName, creatureName, creatureName, creatureName];
}

- (NSString*) makeCreatureChoice
{
    forestCreature = rand() % kSGForestCreature_Amount;
    
    NSString* imageFile = nil;
    switch (forestCreature) {
        case kSGForestCreature_Bat:
            imageFile = @"Bat";
            break;
        case kSGForestCreature_Dog:
            imageFile = @"Dog";            
            break;
        case kSGForestCreature_Duck:
            imageFile = @"Duck";            
            break;
        case kSGForestCreature_Elephant:
            imageFile = @"Elephant";            
            break;
        case kSGForestCreature_Fox:
            imageFile = @"Fox";            
            break;
        case kSGForestCreature_Frog:
            imageFile = @"Frog";            
            break;
        case kSGForestCreature_Kitty:
            imageFile = @"Kitty";            
            break;
        case kSGForestCreature_Lion:
            imageFile = @"Lion";            
            break;
        case kSGForestCreature_Panda:
            imageFile = @"Panda";            
            break;
        case kSGForestCreature_Penguin:
            imageFile = @"Penguin";            
            break;
        case kSGForestCreature_Rat:
            imageFile = @"Rat";            
            break;
        case kSGForestCreature_Tuqui: 
            imageFile = @"Tuqui";            
            break;
        default:
            break;
    }

    return imageFile;
}

@end
