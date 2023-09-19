-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.1.0, 04|05|2023
-- @filename: main.lua

-- Changelog (1.0.0.1):
-- adaptation to new functions of mod

-- Changelog (1.0.0.2):
-- updated to patch 1.4.1

-- Changelog (1.0.0.3):
-- improved and more clearly code
-- fixed compatibility with Precision Farming DLC

-- Changelog (1.0.0.4):
-- merged code to make it more clearly and to avoid unnecessery files

-- Changelog (1.0.0.5):
-- fixed lua error while harvesting maize/sunflower

-- Changelog (1.0.0.6):
-- fixed lua error while collecting vines/grapes

-- Changelog (1.0.0.7):
-- merged code to make it more clearly and to avoid unnecessery files

-- Changelog (1.0.0.8):
-- improved and more clearly code
-- minor bugs fixed

-- Changelog (1.0.0.9):
-- cleaned code

-- Changelog (1.0.1.0):
-- fixed lua error while collecting vines/grapes

local STRAW_YIELD_CHANCE = 16 -- 1/16

function overwriteGameFunctions()
  local function processCutterArea(superFunc, self, workArea, dt)
    local spec = self.spec_cutter

    if spec.workAreaParameters.combineVehicle ~= nil then
      local xs, ys, zs = getWorldTranslation(workArea.start)
      local xw, yw, zw = getWorldTranslation(workArea.width)
      local xh, yh, zh = getWorldTranslation(workArea.height)
      local lastRealArea = 0
      local lastThreshedArea = 0
      local lastArea = 0
      local fieldGroundSystem = g_currentMission.fieldGroundSystem

      for _, fruitTypeIndex in ipairs(spec.workAreaParameters.fruitTypesToUse) do
        local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
        local chopperValue = fieldGroundSystem:getChopperTypeValue(fruitTypeDesc.chopperTypeIndex)
        local realArea, area, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc, growthState, _, terrainDetailPixelsSum = FSDensityMapUtil.cutFruitArea(fruitTypeIndex, xs, zs, xw, zw, xh, zh, true, spec.allowsForageGrowthState, chopperValue)
        local fillType = g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(fruitTypeIndex)

        if fillType ~= nil then
          local lsx, lsy, lsz, lex, ley, lez, lineRadius = DensityMapHeightUtil.getLineByAreaDimensions(xs, ys, zs, xw, yw, zw, xh, yh, zh)
          local pickedUpLiters = -DensityMapHeightUtil.tipToGroundAroundLine(self, -math.huge, fillType, lsx, lsy, lsz, lex, ley, lez, lineRadius, nil, nil, false, nil)

          if pickedUpLiters > 0 then
            local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
            local literPerSqm = fruitDesc.literPerSqm
            local lastCutterArea = pickedUpLiters / (g_currentMission:getFruitPixelsToSqm() * literPerSqm) / 16

            if fruitTypeIndex ~= spec.currentInputFruitType then
              spec.currentInputFruitType = fruitTypeIndex
              spec.currentOutputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.currentInputFruitType)

              if spec.fruitTypeConverters[spec.currentInputFruitType] ~= nil then
                spec.currentOutputFillType = spec.fruitTypeConverters[spec.currentInputFruitType].fillTypeIndex
                spec.currentConversionFactor = spec.fruitTypeConverters[spec.currentInputFruitType].conversionFactor
              end
            end

            spec.useWindrow = true
            spec.currentInputFillType = fillType
            spec.workAreaParameters.lastFruitType = fruitTypeIndex
            spec.workAreaParameters.lastRealArea = spec.workAreaParameters.lastRealArea + lastCutterArea
            spec.workAreaParameters.lastArea = spec.workAreaParameters.lastArea + lastCutterArea
            spec.workAreaParameters.lastChopperValue = chopperValue
            spec.isWorking = true

            break
          end
        end

        if realArea > 0 then
          if self.isServer then
            if growthState ~= spec.currentGrowthState then
              spec.currentGrowthStateTimer = spec.currentGrowthStateTimer + dt

              if spec.currentGrowthStateTimer > 500 or spec.currentGrowthStateTime + 1000 < g_time then
                spec.currentGrowthState = growthState
                spec.currentGrowthStateTimer = 0
              end
            else
              spec.currentGrowthStateTimer = 0
              spec.currentGrowthStateTime = g_time
            end

            if fruitTypeIndex ~= spec.currentInputFruitType then
              spec.currentInputFruitType = fruitTypeIndex
              spec.currentOutputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.currentInputFruitType)

              if spec.fruitTypeConverters[spec.currentInputFruitType] ~= nil then
                spec.currentOutputFillType = spec.fruitTypeConverters[spec.currentInputFruitType].fillTypeIndex
                spec.currentConversionFactor = spec.fruitTypeConverters[spec.currentInputFruitType].conversionFactor
              end

              local cutHeight = g_fruitTypeManager:getCutHeightByFruitTypeIndex(fruitTypeIndex, spec.allowsForageGrowthState)

              self:setCutterCutHeight(cutHeight)
            end

            self:setTestAreaRequirements(fruitTypeIndex, nil, spec.allowsForageGrowthState)

            if terrainDetailPixelsSum > 0 then
              spec.currentInputFruitTypeAI = fruitTypeIndex
            end

            spec.currentInputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitTypeIndex)
            spec.useWindrow = false
          end

          local multiplier = g_currentMission:getHarvestScaleMultiplier(fruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc)

          lastRealArea = realArea * multiplier
          lastThreshedArea = realArea
          lastArea = area

          spec.workAreaParameters.lastFruitType = fruitTypeIndex
          spec.workAreaParameters.lastChopperValue = chopperValue

          break
        end
      end

      if lastArea > 0 then
        if workArea.chopperAreaIndex ~= nil and spec.workAreaParameters.lastChopperValue ~= nil then
          local chopperWorkArea = self:getWorkAreaByIndex(workArea.chopperAreaIndex)

          if chopperWorkArea ~= nil then
            xs, _, zs = getWorldTranslation(chopperWorkArea.start)
            xw, _, zw = getWorldTranslation(chopperWorkArea.width)
            xh, _, zh = getWorldTranslation(chopperWorkArea.height)

            FSDensityMapUtil.setGroundTypeLayerArea(xs, zs, xw, zw, xh, zh, spec.workAreaParameters.lastChopperValue)
          else
            workArea.chopperAreaIndex = nil

            Logging.xmlWarning(self.xmlFile, "Invalid chopperAreaIndex '%d' for workArea '%d'!", workArea.chopperAreaIndex, workArea.index)
          end
        end

        spec.stoneLastState = FSDensityMapUtil.getStoneArea(xs, zs, xw, zw, xh, zh)
        spec.isWorking = true
      end

      spec.workAreaParameters.lastRealArea = spec.workAreaParameters.lastRealArea + lastRealArea
      spec.workAreaParameters.lastThreshedArea = spec.workAreaParameters.lastThreshedArea + lastThreshedArea
      spec.workAreaParameters.lastStatsArea = spec.workAreaParameters.lastStatsArea + lastThreshedArea
      spec.workAreaParameters.lastArea = spec.workAreaParameters.lastArea + lastArea
    end

    return spec.workAreaParameters.lastRealArea, spec.workAreaParameters.lastArea
  end

  local function addCutterArea(superFunc, self, area, realArea, inputFruitType, outputFillType, strawRatio, strawGroundType, farmId, cutterLoad)
    local spec = self.spec_combine

    if area > 0 and (spec.lastCuttersFruitType == FruitType.UNKNOWN or spec.lastCuttersArea == 0 or spec.lastCuttersOutputFillType == outputFillType) then
      spec.lastCuttersArea = spec.lastCuttersArea + area
      spec.lastCuttersOutputFillType = outputFillType
      spec.lastCuttersInputFruitType = inputFruitType
      spec.lastCuttersAreaTime = g_currentMission.time

      if not spec.swath.isAvailable then
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)

        spec.isSwathActive = not fruitDesc.hasWindrow
      end

      local litersPerSqm = 60
      local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)

      if fruitDesc.windrowLiterPerSqm ~= nil then
        litersPerSqm = fruitDesc.windrowLiterPerSqm
      end

      if self:getIsThreshingDuringRain() and self.propertyState ~= Vehicle.PROPERTY_STATE_MISSION then
        realArea = realArea * (1 - Combine.RAIN_YIELD_REDUCTION)
      end

      if self:getFillUnitLastValidFillType(spec.fillUnitIndex) == outputFillType or self:getFillUnitLastValidFillType(spec.bufferFillUnitIndex) == outputFillType then
        local liters = (realArea * g_currentMission:getFruitPixelsToSqm() * litersPerSqm) * strawRatio

        if liters > 0 then
          local inputBuffer = spec.processing.inputBuffer
          local slot = inputBuffer.buffer[inputBuffer.fillIndex]

          slot.area = slot.area + area
          slot.realArea = slot.realArea + realArea
          slot.liters = slot.liters + liters
          slot.inputLiters = slot.inputLiters + liters
          slot.strawRatio = strawRatio
          slot.strawGroundType = strawGroundType
          slot.effectDensity = cutterLoad * strawRatio * 0.8 + 0.2
        end
      end

      if spec.fillEnableTime == nil then
        spec.fillEnableTime = g_currentMission.time + spec.processing.toggleTime
      end

      local pixelToSqm = g_currentMission:getFruitPixelsToSqm()
      local literPerSqm = 1

      if inputFruitType ~= FruitType.UNKNOWN then
        fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
        literPerSqm = fruitDesc.literPerSqm
      end

      local sqm = realArea * pixelToSqm
      local deltaFillLevel = sqm * literPerSqm * spec.threshingScale
      local fillType = outputFillType

      if spec.additives.available then
        local fillTypeSupported = false

        for i = 1, #spec.additives.fillTypes do
          if fillType == spec.additives.fillTypes[i] then
            fillTypeSupported = true

            break
          end
        end

        if fillTypeSupported then
          local additivesFillLevel = self:getFillUnitFillLevel(spec.additives.fillUnitIndex)

          if additivesFillLevel > 0 then
            local usage = spec.additives.usage * deltaFillLevel

            if usage > 0 then
              local availableUsage = math.min(additivesFillLevel / usage, 1)

              deltaFillLevel = deltaFillLevel * (1 + 0.05 * availableUsage)

              self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.additives.fillUnitIndex, -usage, self:getFillUnitFillType(spec.additives.fillUnitIndex), ToolType.UNDEFINED)
            end
          end
        end
      end

      self:setWorkedHectars(spec.workedHectars + MathUtil.areaToHa(realArea, g_currentMission:getFruitPixelsToSqm()))

      if farmId ~= AccessHandler.EVERYONE then
        local damage = self:getVehicleDamage()

        if damage > 0 then
          deltaFillLevel = deltaFillLevel * (1 - damage * Combine.DAMAGED_YIELD_REDUCTION)
        end
      end

      if self:getFillUnitCapacity(spec.fillUnitIndex) == math.huge and self:getFillUnitFillLevel(spec.fillUnitIndex) > 0.001 then
        if spec.lastDischargeTime + spec.fillLevelBufferTime < g_time then
          return deltaFillLevel
        end
      end

      local fillUnitIndex = spec.fillUnitIndex

      if spec.bufferFillUnitIndex ~= nil then
        if self:getFillUnitFreeCapacity(spec.bufferFillUnitIndex) > 0 then
          fillUnitIndex = spec.bufferFillUnitIndex
        end
      end

      if spec.loadingDelay > 0 then
        for i = 1, #spec.loadingDelaySlots do
          if not spec.loadingDelaySlots[i].valid then
            spec.loadingDelaySlots[i].valid = true
            spec.loadingDelaySlots[i].fillLevelDelta = deltaFillLevel
            spec.loadingDelaySlots[i].fillType = fillType

            if spec.loadingDelaySlotsDelayedInsert then
              spec.loadingDelaySlots[i].time = g_time
            else
              spec.loadingDelaySlots[i].time = g_time + (spec.unloadingDelay - spec.loadingDelay)
            end

            spec.loadingDelaySlotsDelayedInsert = not spec.loadingDelaySlotsDelayedInsert

            break
          end
        end

        return deltaFillLevel
      end

      local loadInfo = self:getFillVolumeLoadInfo(spec.loadInfoIndex)

      for cutter, _ in pairs(spec.attachedCutters) do
        if cutter ~= nil and cutter.spec_cutter ~= nil then
          if cutter.spec_cutter.useWindrow and (g_fillTypeManager:getFillTypeNameByIndex(g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(cutter.spec_cutter.currentInputFruitType)) == "STRAW") then
            local randomYield = math.random(1, STRAW_YIELD_CHANCE)

            if randomYield == 1 then
              return self:addFillUnitFillLevel(self:getOwnerFarmId(), fillUnitIndex, deltaFillLevel, fillType, ToolType.UNDEFINED, loadInfo)
            end

            return 0
          end
        end
      end

      return self:addFillUnitFillLevel(self:getOwnerFarmId(), fillUnitIndex, deltaFillLevel, fillType, ToolType.UNDEFINED, loadInfo)
    end

    return 0
  end

  Cutter["processCutterArea"] = function (...)
    return processCutterArea(Cutter["processCutterArea"], ...)
  end

  Combine["addCutterArea"] = function (...)
    return addCutterArea(Combine["addCutterArea"], ...)
  end
end

overwriteGameFunctions()