//
//  ViewController.m
//  TranscodeDemo
//
//  Created by kenny on 7/8/16.
//  Copyright © 2016 kenny. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
        NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"demo.mp4" ofType:nil];
        [self transcodeWithFilePath:videoPath destinationPath:[self tempVideoPath]];
}

-(void)transcodeWithFilePath:(NSString *)path destinationPath:(NSString*)destPath{
    NSError *error = nil;
    CMTime totalDuration = kCMTimeZero;
    // 视频素材
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    if (!asset) {
        return;
    }
    // 视轨
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVAssetTrack *audioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    // 视频插入视频轨，音频插入音频轨
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init]; // 工程文件
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                        ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] count]>0?audioAssetTrack:nil
                         atTime:totalDuration
                          error:nil];
    
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                        ofTrack:videoAssetTrack
                         atTime:totalDuration
                          error:&error];
    if (error) {
        NSAssert(NO,@"不支持改视频");
        return ;
    }
    // 得到所有的视频素材
    AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    totalDuration = CMTimeAdd(totalDuration, asset.duration);
    
    
    CGSize renderSize = CGSizeMake(568, 320);// 产品要求568*320
    CGFloat rate = 1;
    rate = MIN(renderSize.width/videoAssetTrack.naturalSize.width, renderSize.height/videoAssetTrack.naturalSize.height);
    
    
    CGAffineTransform layerTransform = CGAffineTransformMake(videoAssetTrack.preferredTransform.a, videoAssetTrack.preferredTransform.b, videoAssetTrack.preferredTransform.c, videoAssetTrack.preferredTransform.d, videoAssetTrack.preferredTransform.tx * rate, videoAssetTrack.preferredTransform.ty * rate);
    CGAffineTransform t = layerTransform;
    if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
        // Portrait
        renderSize = CGSizeMake(videoAssetTrack.naturalSize.height*rate, videoAssetTrack.naturalSize.width*rate);
        //        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, (videoAssetTrack.naturalSize.width - videoAssetTrack.naturalSize.height) / 2.0 *rate, 0));
    }else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
        // PortraitUpsideDown
        renderSize = CGSizeMake(videoAssetTrack.naturalSize.height*rate, videoAssetTrack.naturalSize.width*rate);
        //        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, (videoAssetTrack.naturalSize.width - videoAssetTrack.naturalSize.height) / 2.0 *rate, 0));
    }else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
        // LandscapeRight
        renderSize = CGSizeMake(videoAssetTrack.naturalSize.width*rate, videoAssetTrack.naturalSize.height*rate);
        //        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, (videoAssetTrack.naturalSize.width - videoAssetTrack.naturalSize.height) / 2.0 *rate));
    }else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
        // LandscapeLeft
        renderSize = CGSizeMake(videoAssetTrack.naturalSize.width*rate, videoAssetTrack.naturalSize.height*rate);
        //        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, (videoAssetTrack.naturalSize.width - videoAssetTrack.naturalSize.height) / 2.0 *rate));
    }
    if (videoAssetTrack.naturalSize.width == videoAssetTrack.naturalSize.height) {
        renderSize = CGSizeMake(480, 480);
    }
    layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
    [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
    [layerInstruciton setOpacity:0.0 atTime:totalDuration];
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    [layerInstructionArray addObject:layerInstruciton];
    
    // 存储路径
    NSString *fileName = destPath;
    NSURL *convertFileURL = [NSURL fileURLWithPath:fileName];
    // 得到视频轨道
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    mainCompositionInst.renderSize = renderSize;
    // 导出
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = convertFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    if (exporter.estimatedOutputFileLength > 35*1024*1024) {
        NSLog(@"视频文件太大");
        return;
    }
//    [self startTimerWithView:pickervew exporter:exporter];
    [exporter exportAsynchronouslyWithCompletionHandler:^{
//        [self stopTimer];
        switch (exporter.status)
        {
            case AVAssetExportSessionStatusFailed:
            {
                NSLog(@"Fail %@",exporter.error);
                break;
            }
            case AVAssetExportSessionStatusCompleted:
            {
                NSLog(@"complete !!!!!!!");
                break;
            }
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"CANCELED");
                break;
            }
        };
    }];
    
    
    
}
-(NSString*)tempVideoPath{
    NSString *tempDir = NSTemporaryDirectory();
    return [tempDir stringByAppendingPathComponent:@"tempVideo.mp4"];
}
@end
