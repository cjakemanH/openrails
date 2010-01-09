﻿/* TimeTable
 * 
 * Constructs a timetable that can be used for dispatching AI trains.
 * 
/// COPYRIGHT 2009 by the Open Rails project.
/// This code is provided to enable you to contribute improvements to the open rails program.  
/// Use of the code for any other purpose or distribution of the code to anyone else
/// is prohibited without specific written permission from admin@openrails.org.
 */
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using Microsoft.Xna.Framework;
using MSTS;

namespace ORTS
{
    public class TimeTable : Dictionary<int, TTTrainTimes>
    {
        public Dispatcher Dispatcher;
        /// <summary>
        /// Processes AI train paths in priority order to construct a feasible timetable.
        /// </summary>
        public TimeTable(Dispatcher dispatcher)
        {
            Dispatcher = dispatcher;
            Heap<AITrain> trains = new Heap<AITrain>();
            foreach (KeyValuePair<int, AITrain> kvp in dispatcher.AI.AITrainDictionary)
                trains.Add(kvp.Value.Priority * 24 * 60 * 60 + kvp.Value.StartTime, kvp.Value);
            for (AITrain train = trains.DeleteMin(); train != null; train = trains.DeleteMin())
            {
                TTTrainTimes times = new TTTrainTimes(train);
                for (int tries = 0; tries < 2; tries++)
                {
                    int d = CalcTrackTimes(train.StartTime, train.StartTime + train.PassTime(), train.Path.FirstNode, times, -1);
                    if (d == 0)
                    {
                        Add(times);
                        break;
                    }
                    train.StartTime += d;
                    //Console.WriteLine("new starttime {0}", train.StartTime);
                }
                if (!ContainsKey(train.UiD))
                    Console.WriteLine("cannot add train {0} to timetable", train.UiD);
            }
        }

        // restore game state
        public TimeTable(Dispatcher dispatcher, int nTrains, BinaryReader inf)
        {
            Dispatcher = dispatcher;
            for (int i = 0; i < nTrains; i++)
            {
                int uid = inf.ReadInt32();
                TTTrainTimes times = new TTTrainTimes(dispatcher.AI.AITrainDictionary[uid], inf);
                Add(times);
            }
        }

        // save game state
        public void Save(BinaryWriter outf)
        {
            outf.Write(Count);
            foreach (KeyValuePair<int, TTTrainTimes> kvp in this)
            {
                outf.Write(kvp.Key);
                kvp.Value.Save(outf);
            }
        }

        /// <summary>
        /// Recursive function that tries to built a list of times for a train that does not overlap any trains already in the timetable.
        /// Returns the number of seconds the train needs to wait at a previous node.
        /// </summary>
        private int CalcTrackTimes(double atime, double ltime, AIPathNode node, TTTrainTimes times, int prevIndex)
        {
            if (prevIndex >= 0 && prevIndex != node.NextMainTVNIndex && prevIndex != node.NextSidingTVNIndex)
            {
                int offset = TestAdd(prevIndex, atime, ltime);
                if (offset > 0)
                    return offset;
            }
            if (node.JunctionIndex >= 0)
            {
                int offset = TestAdd(node.JunctionIndex, ltime - times.Train.PassTime(), ltime);
                if (offset > 0)
                    return offset;
            }
            double nextATime = atime;
            double nextLTime = ltime;
            switch (node.Type)
            {
                case AIPathNodeType.Stop:
                case AIPathNodeType.Reverse:
                case AIPathNodeType.Uncouple:
                    nextLTime += node.WaitTimeS + times.Train.StopStartTime();
                    break;
                default:
                    break;
            }
            int nextIndex = node.NextMainTVNIndex;
            AIPathNode nextNode = node.NextMainNode;
            if (nextIndex == -1)
            {
                nextIndex = node.NextSidingTVNIndex;
                nextNode = node.NextSidingNode;
            }
            if (nextIndex == -1)
            {
                times.Add(prevIndex, atime, ltime);
                times.Add(node.JunctionIndex, ltime - times.Train.PassTime(), ltime);
                return 0;
            }
            if (nextIndex != prevIndex)
            {
                nextATime = nextLTime - times.Train.PassTime();
                nextLTime += Dispatcher.trackLength[nextIndex] / times.Train.MaxSpeedMpS;
            }
            int delay = CalcTrackTimes(nextATime, nextLTime, nextNode, times, nextIndex);
            if (delay == 0)
            {
                times.Add(prevIndex, atime, ltime);
                times.Add(node.JunctionIndex, ltime - times.Train.PassTime(), ltime);
                return 0;
            }
            if (node.JunctionIndex < 0)
                return delay;
            if (node.Type == AIPathNodeType.SidingStart)
            {
                double nextSLTime = nextATime + times.Train.PassTime() + Dispatcher.trackLength[node.NextSidingTVNIndex] / times.Train.MaxSpeedMpS;
                int delay1 = CalcTrackTimes(nextATime, nextSLTime, node.NextSidingNode, times, node.NextSidingTVNIndex);
                if (delay1 == 0)
                {
                    times.Add(prevIndex, atime, ltime);
                    times.Add(node.JunctionIndex, ltime - times.Train.PassTime(), ltime);
                    return 0;
                }
            }
            if (prevIndex < 0)
                return delay;
            ltime += delay;
            int offset1 = TestAdd(prevIndex, atime, ltime);
            if (offset1 == 0)
            {
                nextATime += delay;
                nextLTime += delay;
                offset1 = CalcTrackTimes(nextATime, nextLTime, nextNode, times, nextIndex);
                if (offset1 == 0)
                {
                    times.Add(prevIndex, atime, ltime);
                    times.Add(node.JunctionIndex, ltime - times.Train.PassTime(), ltime);
                    //Console.WriteLine("train {0} has to wait {1} at {2}", times.Train.UiD, delay, node.JunctionIndex);
                    return 0;
                }
            }
            return delay + offset1;
        }

        /// <summary>
        /// Returns true if a new train can be added to the timetable without overlapping an existing train.
        /// </summary>
        public bool CanAdd(TTTrainTimes times)
        {
            foreach (KeyValuePair<int, TTTrainTimes> kvp in this)
            {
                if (kvp.Value.Overlap(times))
                    return false;
            }
            return true;
        }
 
        /// <summary>
        /// Adds a train to the timetable if possible.
        /// </summary>
        public void Add(TTTrainTimes times)
        {
            if (!CanAdd(times))
                return;
            this[times.Train.UiD] = times;
        }

        /// <summary>
        /// Returns true if the specified track and time interval can be added to the timetable without overlapping an existing train.
        /// </summary>
        public int TestAdd(int trackIndex, double arrive, double leave)
        {
            int result = 0;
            foreach (KeyValuePair<int, TTTrainTimes> kvp in this)
            {
                if (!kvp.Value.ContainsKey(trackIndex))
                    continue;
                TimeTableTime tt = kvp.Value[trackIndex];
                if (!tt.Overlap(new TimeTableTime(arrive, leave)))
                    continue;
                int diff = tt.Leave - (int)arrive + 1;
                //Console.WriteLine("cannot add {0} {1} {2} {3} {4} {5}", trackIndex, diff, tt.Arrive, tt.Leave, arrive, leave);
                if (result < diff)
                    result = diff;
            }
            return result;
        }
    }

    /// <summary>
    /// Class used to store timetable times for a single train.
    /// Times are saved by track node index.
    /// </summary>
    public class TTTrainTimes : Dictionary<int, TimeTableTime>
    {
        public AITrain Train;
        public TTTrainTimes(AITrain train)
        {
            Train = train;
        }

        // restore game state
        public TTTrainTimes(AITrain train, BinaryReader inf)
        {
            Train = train;
            int n = inf.ReadInt32();
            for (int i = 0; i < n; i++)
            {
                int index = inf.ReadInt32();
                int atime = inf.ReadInt32();
                int ltime = inf.ReadInt32();
                Add(index, atime, ltime);
            }
        }

        // save game state
        public void Save(BinaryWriter outf)
        {
            outf.Write(Count);
            foreach (KeyValuePair<int, TimeTableTime> kvp in this)
            {
                outf.Write(kvp.Key);
                outf.Write(kvp.Value.Arrive);
                outf.Write(kvp.Value.Leave);
            }
        }

        /// <summary>
        /// Adds an entry for the specified track node.
        /// </summary>
        public void Add(int trackIndex, double arrive, double leave)
        {
            if (trackIndex < 0 || this.ContainsKey(trackIndex))
                return;
            this[trackIndex] = new TimeTableTime(arrive, leave);
            //Console.WriteLine("add {0} {1} {2} {3} {4}", Train.UiD, trackIndex, arrive, leave, leave - arrive);
        }
        /// <summary>
        /// Returns true if any of two trains's time intervals overlap.
        /// </summary>
        public bool Overlap(TTTrainTimes other)
        {
            foreach (KeyValuePair<int, TimeTableTime> kvp in this)
            {
                if (!other.ContainsKey(kvp.Key))
                    continue;
                if (kvp.Value.Overlap(other[kvp.Key]))
                {
                    //Console.WriteLine("overlap {0} {1} {2}", Train.UiD, other.Train.UiD, kvp.Key);
                    return true;
                }
            }
            return false;
        }
    }

    /// <summary>
    /// Struct to store and compare timetable time intervals.
    /// </summary>
    public struct TimeTableTime
    {
        public int Arrive;
        public int Leave;
        public TimeTableTime(double arrive, double leave)
        {
            Arrive = (int)arrive;
            Leave = 1 + (int)leave;
        }
        /// <summary>
        /// Returns true if two time intervals overlap.
        /// </summary>
        public bool Overlap(TimeTableTime other)
        {
            return Arrive <= other.Leave && Leave >= other.Arrive;
        }
    }
}
