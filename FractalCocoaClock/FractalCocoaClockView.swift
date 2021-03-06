//
//  FractalCocoaClockView.swift
//  FractalCocoaClock
//
//  Created by Kevin on 2019-03-31.
//  Copyright © 2019 Kevin Chow. All rights reserved.
//

import Cocoa
import ScreenSaver

typealias Rotator = (scaledcos: CGFloat, scaledsin: CGFloat)

class FractalCocoaClockView: ScreenSaverView {

    let maxDepth = 32
    let colourGenerationScale: CGFloat = 0.85
    let generationScaleMax: CGFloat = 1
    let generationScaleMin: CGFloat = 0.793700525984099737375852819636
    let expansionPattern: Array<CGFloat> = [60, 12, 60, 12]

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    /**
     * Generate a variable fractal scale for more interesting designs
     * @param now {CGFloat} The current time
     *
     * @returns {CGFloat} The scale to use between fractal generations
     */
    func getVariableScale(now: CGFloat) -> CGFloat {
        let patternValue = now.truncatingRemainder(dividingBy: expansionPattern.reduce(0, +))

        if (patternValue <= expansionPattern[0]) {
            return generationScaleMin
        } else if (patternValue <= expansionPattern.prefix(2).reduce(0, +)) {
            return generationScaleMax +
              (generationScaleMin - generationScaleMax) *
              (cos(CGFloat.pi * (patternValue - expansionPattern[0]) / expansionPattern[1]) + 1) * 0.5
        } else if (patternValue <= expansionPattern.prefix(3).reduce(0, +)) {
            return generationScaleMax
        } else {
            return generationScaleMin +
              (generationScaleMax - generationScaleMin) *
              (cos(CGFloat.pi *
                     (patternValue - expansionPattern.prefix(3).reduce(0, +))
                     / expansionPattern[3]) + 1) * 0.5
        }
    }

    /**
     * Create a Rotator tuple from a rotation and a scale
     * @param rotation {CGFloat} Angle in radians from 0 to 2pi expressing a clock hand position
     * @param scale {CGFloat} Scale relative to previous generation
     *
     * @returns {Rotator} Tuple of x and y rotation*scale components
     */
    func getRotator(rotation: CGFloat, scale: CGFloat) -> Rotator {
        var returnRotator: Rotator

        returnRotator.scaledcos = cos(rotation) * scale
        returnRotator.scaledsin = sin(rotation) * scale

        return returnRotator
    }

    /**
     * Apply a rotator to a hand
     * @param rotator {Rotator} The rotation*scale tuple to apply
     * @param size {NSSize} The hand to rotate
     *
     * @returns {NSSize} The rotated and scaled hand
     */
    func rotateSize(rotator: Rotator, size: NSSize) -> NSSize {
        return NSMakeSize(size.width * rotator.scaledcos - size.height * rotator.scaledsin,
                          size.width * rotator.scaledsin + size.height * rotator.scaledcos)
    }

    /**
     * Return the time to display
     * @param isPreview {Bool} If set to true, accelerate time by 6 times
     *
     * @returns The number of seconds since midnight, possibly accelerated
     */
    func getNow(isPreview: Bool) -> CGFloat {
        let date = Date()
        let calendar = Calendar.current
        let hours = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        let nanoseconds = calendar.component(.nanosecond, from: date)
        let nanosecondsPerSecond = 1000*1000*1000

        let integerSeconds = ((hours * 60) + minutes) * 60 + seconds
        var now: CGFloat = CGFloat(integerSeconds) + CGFloat(nanoseconds) / CGFloat(nanosecondsPerSecond)
        if (isPreview) {
            now = (now * 6).remainder(dividingBy: 60 * 60 * 24)
        }
        return now
    }

    /**
     * Return rotation angle that a hand would have given a period
     * @param now {CGFloat} The time since midnight
     * @param period {CGFloat} The number of seconds in one rotation
     *
     * @returns {CGFloat} The radians from 0 on a clock that now/period would display
     */
    func getRotation(now: CGFloat, period: CGFloat) -> CGFloat {
        return -2 * CGFloat.pi * now.remainder(dividingBy: period) / period
    }

    /**
     * Return hour hand drawing object and minute and second relative rotations
     * @param isPreview {Bool} Boolean flag whether this screensaver is being previewed
     * @param bounds {NSRect} The bounding rectangle of this view, may be entire screen or preview window
     *
     * @returns hour {NSRect} The hour hand
     * @returns minuteRotator {Rotator} The scaled rotation of the minute hand relative to the hour hand
     * @returns secondRotator {Rotator} The scaled rotation of the second hand relative to the hour hand
     */
    func getHandRotations(isPreview: Bool,
                          bounds: NSRect) -> (hour: NSRect,
                                              minuteRotator: Rotator,
                                              secondRotator: Rotator) {
        let now = getNow(isPreview: isPreview)
        let hourRotation = getRotation(now: now, period: 12 * 60 * 60)
        let minuteRotation = getRotation(now: now, period: 60 * 60)
        let secondRotation = getRotation(now: now, period: 60)

        let scale = getVariableScale(now: now)

        let hourRotator = getRotator(rotation: hourRotation, scale: 1)
        let minuteRotator = getRotator(rotation: minuteRotation - hourRotation, scale: -scale)
        let secondRotator = getRotator(rotation: secondRotation - hourRotation, scale: -scale)

        let rootSize = min(bounds.size.width, bounds.size.height) / 6
        var root = NSRect()
        root.size = rotateSize(rotator: hourRotator, size: NSMakeSize(0, -rootSize))
        root.origin.x = NSMidX(bounds) - root.size.width
        root.origin.y = NSMidY(bounds) - root.size.height

        return (root, minuteRotator, secondRotator)
    }

    /**
     * Recursively draw a fractal branch
     * @param line {NSRect} The current branch to draw
     * @param relativeSecondRotator {Rotator} The scaled rotation of the second hand relative to the hour hand
     * @param relativeMinuteRotator {Rotator} The scaled rotation of the minute hand relative to the hour hand
     * @param depth {Int} The current fractal depth
     * @param depthLeft {Int} The number of fractal depths to continue drawing
     * @param colour {Array<CGFloat>} The colour of the branch to draw
     */
    func drawBranch(line: NSRect,
                    relativeSecondRotator: Rotator,
                    relativeMinuteRotator: Rotator,
                    depth: Int,
                    depthLeft: Int,
                    colour: Array<CGFloat>) {

        let p2 = NSMakePoint(line.origin.x + line.size.width,
                             line.origin.y + line.size.height)

        if (depthLeft >= 1) {
            var newLine = NSRect()
            newLine.origin = p2
            var newColour = colour
            newColour[1] = 0.92 * colour[1]

            newLine.size = rotateSize(rotator: relativeSecondRotator, size: line.size)
            newColour[0] = colourGenerationScale * colour[0]
            newColour[2] = 0.1 + colourGenerationScale * colour[2]
            drawBranch(line: newLine,
                       relativeSecondRotator: relativeSecondRotator,
                       relativeMinuteRotator: relativeMinuteRotator,
                       depth: depth + 1,
                       depthLeft: depthLeft - 1,
                       colour: newColour)

            newLine.size = rotateSize(rotator: relativeMinuteRotator, size: line.size)
            newColour[0] = 0.1 + colourGenerationScale * colour[0]
            newColour[2] = colourGenerationScale * colour[2]
            drawBranch(line: newLine,
                       relativeSecondRotator: relativeSecondRotator,
                       relativeMinuteRotator: relativeMinuteRotator,
                       depth: depth + 1,
                       depthLeft: depthLeft - 1,
                       colour: newColour)
        }

        let alpha = (depth == 0) ? 1: (1 / CGFloat(depth))

        NSColor.init(red: colour[0], green: colour[1], blue: colour[2], alpha: alpha).setStroke()

        let linePath = NSBezierPath()
        linePath.lineWidth = 2
        if (depth == 0) {
            linePath.move(to: CGPoint(x: line.origin.x + line.size.width * 0.5,
                                      y: line.origin.y + line.size.height * 0.5))
        } else {
            linePath.move(to: CGPoint(x: line.origin.x,
                                      y: line.origin.y))
        }
        linePath.line(to: CGPoint(x: p2.x,
                                  y: p2.y))
        linePath.stroke()
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)


        let (hourHand, minuteRotator, secondRotator) = getHandRotations(isPreview: self.isPreview, bounds: self.bounds)

        drawBranch(line: hourHand,
                   relativeSecondRotator: secondRotator,
                   relativeMinuteRotator: minuteRotator,
                   depth: 0,
                   depthLeft: 10,
                   colour: [1, 1, 1])
    }

    override func animateOneFrame() {
        needsDisplay = true;
    }

}
