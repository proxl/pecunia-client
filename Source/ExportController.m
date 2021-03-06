/**
 * Copyright (c) 2008, 2013, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "ExportController.h"
#import "BankingCategory.h"
#import "BankStatement.h"
#import "ShortDate.h"
#import "StatCatAssignment.h"

static ExportController *exportController = nil;

@implementation ExportController

- (id)init
{
    self = [super init];
    exportController = self;
    selectedFields = [NSMutableArray arrayWithCapacity: 10];
    return self;
}

+ (ExportController *)controller
{
    return exportController;
}

- (NSArray *)exportedFields
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey: @"Exporter.fields"];
}

- (void)startExport: (BankingCategory *)cat fromDate: (ShortDate *)from toDate: (ShortDate *)to
{
    NSSavePanel *sp;
    NSError     *error = nil;
    int         runResult;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // which fields shall be exported?
    NSArray *fields = [self exportedFields];
    if (fields == nil) {
        NSRunAlertPanel(NSLocalizedString(@"AP810", nil),
                        NSLocalizedString(@"AP104", nil),
                        NSLocalizedString(@"AP1", nil),
                        nil,
                        nil);
        return;
    }

    [self setValue:  [to highDate] forKey: @"toDate"];
    [self setValue:  [from lowDate] forKey: @"fromDate"];

    /* create or get the shared instance of NSSavePanel */
    sp = [NSSavePanel savePanel];

    /* set up new attributes */
    [sp setAccessoryView: accessoryView];
    [sp setTitle: @"Exportdatei wählen"];
    //	[sp setRequiredFileType:@"txt"];

    /* display the NSSavePanel */
    NSString *saveDir = [defaults valueForKey: @"lastExportDirectory"];
    if (saveDir == nil) {
        // todo: to be replaced
        saveDir = NSHomeDirectory();
    }

    [sp setDirectoryURL: [NSURL URLWithString: saveDir]];
    [sp setNameFieldStringValue: [[cat name] stringByAppendingString: @".csv"]];
    runResult = [sp runModal];

    /* if successful, save file under designated name */
    if (runResult == NSOKButton) {
        // init date formatter
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle: NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle: NSDateFormatterNoStyle];

        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.usesSignificantDigits = NO;
        numberFormatter.minimumFractionDigits = 2;
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;

        NSMutableString *res = [NSMutableString stringWithCapacity: 1000];
        NSArray         *cats = [[cat allCategories] allObjects];

        ShortDate *from_Date = [ShortDate dateWithDate: fromDate];
        ShortDate *to_Date = [ShortDate dateWithDate: toDate];

        // addObjectsFromArray
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey: @"statement.date" ascending: NO];
        for (BankingCategory *currentCategory in cats) {
            NSArray *stats = [currentCategory assignmentsFrom: from_Date to: to_Date withChildren: withChildren];
            stats = [stats sortedArrayUsingDescriptors: @[sd]];
            for (StatCatAssignment *stat in stats) {
                NSString *s = [stat stringForFields: fields usingDateFormatter: dateFormatter numberFormatter: numberFormatter];
                [res appendString: s];
            }
        }
        if ([res writeToFile: [[sp URL] path] atomically: NO encoding: NSUTF8StringEncoding error: &error] == NO) {
            NSAlert *alert = [NSAlert alertWithError: error];
            [alert runModal];
            return;
        }

        // save last export directory
        [defaults setValue: [[sp directoryURL] path] forKey: @"lastExportDirectory"];

        // issue success message
        NSRunInformationalAlertPanel(NSLocalizedString(@"AP810", nil),
                                     NSLocalizedString(@"AP811", nil),
                                     NSLocalizedString(@"AP1", nil),
                                     nil, nil,
                                     [[sp URL] path]
                                     );
    }
}

@end
